//
//  StatsView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI
import SwiftData
import Charts
import Accessibility
import LinkPresentation

/// Displays summary statistics and trend charts for all recorded fill-up sessions.
struct StatsView: View {

    @Query(sort: \FillUpEntry.date, order: .reverse) private var entries: [FillUpEntry]
    @State private var mpgShareImage: ChartShareImage? = nil
    @State private var fuelCostShareImage: ChartShareImage? = nil
    @State private var showCalculatedMPG = true
    @State private var showVehicleReportedMPG = true
    /// Cached aggregate statistics. Recomputed only when `entries` changes.
    @State private var stats = StatsSnapshot(entries: [])

    var body: some View {
        if entries.count < 2 {
            emptyStateView
        } else {
            contentScrollView
        }
    }

    // MARK: - Subviews

    /// Prompt shown when fewer than two entries exist.
    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "Not Enough Data"),
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text(String(localized: "Add more fill-ups to see trends."))
        )
        .navigationTitle(String(localized: "Stats"))
        .accessibilityLabel(
            String(localized: "No trend data. Add at least two fill-ups to see statistics and charts.")
        )
    }

    /// Main scrollable content — summary stats and charts.
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                summarySection
                mpgChartSection
                fuelCostChartSection
            }
            .padding()
        }
        .navigationTitle(String(localized: "Stats"))
        .onAppear {
            stats = StatsSnapshot(entries: entries)
        }
        .onChange(of: entries) { _, newEntries in
            stats = StatsSnapshot(entries: newEntries)
        }
        .sheet(item: $mpgShareImage) { share in
            ActivityViewController(image: share.image, title: share.title)
        }
        .sheet(item: $fuelCostShareImage) { share in
            ActivityViewController(image: share.image, title: share.title)
        }
    }

    // MARK: - Summary Section

    /// Aggregate statistics shown at the top of the screen.
    private var summarySection: some View {
        GroupBox(String(localized: "Summary")) {
            VStack(spacing: 8) {
                statRow(
                    label: String(localized: "Fill-Up Sessions"),
                    value: "\(stats.sessionCount)"
                )
                statRow(
                    label: String(localized: "Average MPG"),
                    value: String(format: "%.2f", stats.averageMPG)
                )
                statRow(
                    label: String(localized: "Best MPG"),
                    value: String(format: "%.2f", stats.bestMPG)
                )
                statRow(
                    label: String(localized: "Worst MPG"),
                    value: String(format: "%.2f", stats.worstMPG)
                )
                statRow(
                    label: String(localized: "Total Miles"),
                    value: stats.totalMiles.formatted(.number.precision(.fractionLength(1))) + " mi"
                )
                statRow(
                    label: String(localized: "Total Gallons"),
                    value: stats.totalGallons.formatted(.number.precision(.fractionLength(3))) + " gal"
                )
                if let cost = stats.totalFuelCost {
                    statRow(
                        label: String(localized: "Total Fuel Cost"),
                        value: cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                    )
                }
            }
        }
    }

    // MARK: - Chart Sections

    /// MPG over time chart with optional vehicle-reported MPG overlay.
    private var mpgChartSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                mpgSeriesToggleRow
                mpgChartView
                    .accessibilityChartDescriptor(MPGChartDescriptor(entries: stats.chronologicalEntries))
                Button {
                    if let image = renderImage(from: mpgChartView) {
                        mpgShareImage = ChartShareImage(image: image, title: String(localized: "MPG Over Time"))
                    }
                } label: {
                    Label(
                        String(localized: "Share MPG Chart"),
                        systemImage: "square.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(localized: "Share MPG over time chart"))
                .accessibilityHint(String(localized: "Exports the chart as an image you can share"))
            }
        } label: {
            Text(String(localized: "MPG Over Time"))
                .font(.headline)
        }
    }

    /// Toggle buttons for showing/hiding each MPG series.
    private var mpgSeriesToggleRow: some View {
        HStack(spacing: 8) {
            Toggle(String(localized: "Calculated"), isOn: $showCalculatedMPG)
                .toggleStyle(.button)
                .accessibilityLabel(String(localized: "Show Calculated MPG"))
                .accessibilityHint(String(localized: "Toggles the calculated MPG line on the chart"))
            if stats.hasTruckReportedMPG {
                Toggle(String(localized: "Vehicle-Reported"), isOn: $showVehicleReportedMPG)
                    .toggleStyle(.button)
                    .accessibilityLabel(String(localized: "Show Vehicle-Reported MPG"))
                    .accessibilityHint(String(localized: "Toggles the vehicle-reported MPG line on the chart"))
            }
        }
    }

    /// Fuel cost per gallon chart. Only shown when at least one entry has price data.
    @ViewBuilder
    private var fuelCostChartSection: some View {
        if stats.hasPriceData {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    fuelCostChartView
                        .accessibilityChartDescriptor(
                            FuelCostChartDescriptor(entries: stats.chronologicalEntries)
                        )
                    Button {
                        if let image = renderImage(from: fuelCostChartView) {
                            fuelCostShareImage = ChartShareImage(image: image, title: String(localized: "Cost Per Gallon Over Time"))
                        }
                    } label: {
                        Label(
                            String(localized: "Share Fuel Cost Chart"),
                            systemImage: "square.and.arrow.up"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(String(localized: "Share fuel cost per gallon chart"))
                    .accessibilityHint(String(localized: "Exports the chart as an image you can share"))
                }
            } label: {
                Text(String(localized: "Cost Per Gallon Over Time"))
                    .font(.headline)
            }
        }
    }

    // MARK: - Chart Views

    /// The MPG over time line chart — extracted for use with `ImageRenderer`.
    ///
    /// Renders only the series currently enabled by `showCalculatedMPG` and
    /// `showVehicleReportedMPG`. Shows a placeholder when both are off.
    @ViewBuilder
    private var mpgChartView: some View {
        let showVehicle = stats.hasTruckReportedMPG && showVehicleReportedMPG
        let showLegend = showCalculatedMPG && showVehicle

        if !showCalculatedMPG && !showVehicle {
            Text(String(localized: "Select at least one series to display."))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)
                .accessibilityLabel(String(localized: "No series selected. Enable Calculated or Vehicle-Reported to see the chart."))
        } else {
            Chart {
                if showCalculatedMPG {
                    ForEach(stats.chronologicalEntries) { entry in
                        LineMark(
                            x: .value(String(localized: "Date"), entry.date),
                            y: .value(String(localized: "Calculated MPG"), entry.calculatedMPG)
                        )
                        .foregroundStyle(by: .value(
                            String(localized: "Series"),
                            String(localized: "Calculated")
                        ))
                        .symbol(.circle)
                        .interpolationMethod(.catmullRom)
                    }
                }
                if showVehicle {
                    ForEach(stats.chronologicalEntries.filter { $0.truckReportedMPG != nil }) { entry in
                        LineMark(
                            x: .value(String(localized: "Date"), entry.date),
                            y: .value(String(localized: "Vehicle-Reported MPG"), entry.truckReportedMPG!)
                        )
                        .foregroundStyle(by: .value(
                            String(localized: "Series"),
                            String(localized: "Vehicle-Reported")
                        ))
                        .symbol(.square)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .frame(height: 200)
            .chartLegend(showLegend ? .visible : .hidden)
            .accessibilityLabel(String(localized: "MPG over time line chart"))
        }
    }

    /// The fuel cost per gallon line chart — extracted for use with `ImageRenderer`.
    private var fuelCostChartView: some View {
        Chart {
            ForEach(stats.priceDataEntries) { entry in
                LineMark(
                    x: .value(String(localized: "Date"), entry.date),
                    y: .value(String(localized: "Price Per Gallon"), entry.pricePerGallon!)
                )
                .foregroundStyle(.green)
                .symbol(.circle)
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 200)
        .accessibilityLabel(String(localized: "Fuel cost per gallon over time line chart"))
    }

    // MARK: - Helpers

    /// A labeled row displaying a statistic and its value side by side.
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// Renders a SwiftUI view to a `UIImage` at @3x scale for sharing.
    private func renderImage<V: View>(from view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }

}

// MARK: - ChartShareImage

/// An `Identifiable` wrapper around a rendered chart `UIImage`, used to drive `.sheet(item:)`.
private struct ChartShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
    /// The chart title shown in the share sheet preview header.
    let title: String
}

// MARK: - ChartImageItemSource

/// Provides `LPLinkMetadata` to the share sheet so iOS displays a title and thumbnail
/// preview and correctly identifies the shared item as an image.
private final class ChartImageItemSource: NSObject, UIActivityItemSource {

    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any { image }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? { image }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        let provider = NSItemProvider(object: image)
        metadata.imageProvider = provider
        metadata.iconProvider = provider
        return metadata
    }
}

// MARK: - ActivityViewController

/// A UIKit bridge that presents a `UIActivityViewController` for sharing a chart `UIImage`.
private struct ActivityViewController: UIViewControllerRepresentable {

    /// The image to share.
    let image: UIImage
    /// The title shown in the share sheet preview header.
    let title: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = ChartImageItemSource(image: image, title: title)
        return UIActivityViewController(activityItems: [source], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Accessibility Chart Descriptors

/// VoiceOver audio graph descriptor for the MPG over time chart.
private struct MPGChartDescriptor: AXChartDescriptorRepresentable {

    /// Entries in chronological order.
    let entries: [FillUpEntry]

    func makeChartDescriptor() -> AXChartDescriptor {
        let dates = entries.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        let mpgValues = entries.map(\.calculatedMPG)
        let minMPG = mpgValues.min() ?? 0
        let maxMPG = max(mpgValues.max() ?? 1, minMPG + 1)

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Date"),
            categoryOrder: dates
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "MPG"),
            range: minMPG...maxMPG,
            gridlinePositions: []
        ) { value in String(format: "%.1f MPG", value) }

        let series = AXDataSeriesDescriptor(
            name: String(localized: "Calculated MPG"),
            isContinuous: true,
            dataPoints: entries.map { entry in
                AXDataPoint(
                    x: entry.date.formatted(date: .abbreviated, time: .omitted),
                    y: entry.calculatedMPG,
                    label: String(format: "%.2f MPG", entry.calculatedMPG)
                )
            }
        )
        return AXChartDescriptor(
            title: String(localized: "MPG over time"),
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

/// VoiceOver audio graph descriptor for the fuel cost per gallon over time chart.
private struct FuelCostChartDescriptor: AXChartDescriptorRepresentable {

    /// Entries in chronological order.
    let entries: [FillUpEntry]

    func makeChartDescriptor() -> AXChartDescriptor {
        let priceEntries = entries.filter { $0.pricePerGallon != nil }
        let dates = priceEntries.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        let prices = priceEntries.compactMap(\.pricePerGallon)
        let minPrice = prices.min() ?? 0
        let maxPrice = max(prices.max() ?? 1, minPrice + 0.01)

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Date"),
            categoryOrder: dates
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Price Per Gallon"),
            range: minPrice...maxPrice,
            gridlinePositions: []
        ) { value in String(format: "$%.3f", value) }

        let series = AXDataSeriesDescriptor(
            name: String(localized: "Price Per Gallon"),
            isContinuous: true,
            dataPoints: priceEntries.map { entry in
                AXDataPoint(
                    x: entry.date.formatted(date: .abbreviated, time: .omitted),
                    y: entry.pricePerGallon!,
                    label: String(format: "$%.3f per gallon", entry.pricePerGallon!)
                )
            }
        )
        return AXChartDescriptor(
            title: String(localized: "Fuel cost per gallon over time"),
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - StatsSnapshot

/// A snapshot of aggregate statistics and pre-sorted sequences computed from a collection of
/// fill-up entries. Acts as the single caching boundary for `StatsView` — recomputed once per
/// data change, not once per render.
private struct StatsSnapshot {

    /// Total number of fill-up sessions.
    let sessionCount: Int

    /// Mean calculated MPG across all sessions.
    let averageMPG: Double

    /// Highest calculated MPG in a single session.
    let bestMPG: Double

    /// Lowest calculated MPG in a single session.
    let worstMPG: Double

    /// Sum of all miles driven.
    let totalMiles: Double

    /// Sum of all gallons pumped.
    let totalGallons: Double

    /// Sum of all recorded fuel costs. `nil` if no entries include price data.
    let totalFuelCost: Double?

    /// `true` if at least one entry has a vehicle-reported MPG value.
    let hasTruckReportedMPG: Bool

    /// `true` if at least one entry has price-per-gallon data.
    let hasPriceData: Bool

    /// Entries sorted oldest-first for chronological chart display.
    let chronologicalEntries: [FillUpEntry]

    /// Chronological entries that have price-per-gallon data, for the fuel cost chart.
    let priceDataEntries: [FillUpEntry]

    /// Computes aggregate statistics and pre-sorted sequences from the given entries.
    /// - Parameter entries: The entries to aggregate. Should contain at least two items.
    init(entries: [FillUpEntry]) {
        sessionCount = entries.count
        let mpgValues = entries.map(\.calculatedMPG)
        averageMPG = mpgValues.reduce(0, +) / Double(max(1, entries.count))
        bestMPG = mpgValues.max() ?? 0
        worstMPG = mpgValues.min() ?? 0
        totalMiles = entries.map(\.milesDriven).reduce(0, +)
        totalGallons = entries.map(\.gallonsPumped).reduce(0, +)

        let costs = entries.compactMap(\.totalPricePaid)
        totalFuelCost = costs.isEmpty ? nil : costs.reduce(0, +)
        hasPriceData = entries.contains { $0.pricePerGallon != nil }
        hasTruckReportedMPG = entries.contains { $0.truckReportedMPG != nil }

        let sorted = entries.sorted { $0.date < $1.date }
        chronologicalEntries = sorted
        priceDataEntries = sorted.filter { $0.pricePerGallon != nil }
    }
}

// MARK: - Preview

#Preview("With data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    let ctx = container.mainContext
    ctx.insert(FillUpEntry(
        date: Date().addingTimeInterval(-86400 * 30),
        milesDriven: 312.5, gallonsPumped: 12.8,
        totalPricePaid: 45.60, truckReportedMPG: 24.1
    ))
    ctx.insert(FillUpEntry(
        date: Date().addingTimeInterval(-86400 * 14),
        milesDriven: 280.0, gallonsPumped: 11.5,
        totalPricePaid: 40.25, truckReportedMPG: 23.8
    ))
    ctx.insert(FillUpEntry(
        date: Date().addingTimeInterval(-86400 * 2),
        milesDriven: 340.0, gallonsPumped: 13.1,
        notes: "Highway trip"
    ))
    return NavigationStack {
        StatsView()
    }
    .modelContainer(container)
}

#Preview("Empty state") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    return NavigationStack {
        StatsView()
    }
    .modelContainer(container)
}
