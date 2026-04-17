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
    @State private var yoyShareImage: ChartShareImage? = nil
    @State private var showCalculatedMPG = true
    @State private var showVehicleReportedMPG = true
    /// Cached aggregate statistics. Recomputed only when `entries` changes.
    @State private var stats = StatsSnapshot(entries: [])
    /// Captured content width of the scroll view's LazyVStack, used by `renderImage` to
    /// produce a correctly-sized export image without relying on `UIScreen`.
    @State private var chartExportWidth: CGFloat = 0

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
            description: Text(String(localized: "Add more entries to see trends."))
        )
        .navigationTitle(String(localized: "Stats"))
        .accessibilityLabel(
            String(localized: "No trend data. Add at least two entries to see statistics and charts.")
        )
    }

    /// Main scrollable content — summary stats and charts.
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                summarySection
                mpgChartSection
                yoyChartSection
                fuelCostChartSection
            }
            .padding()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { chartExportWidth = $0 }
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
        .sheet(item: $yoyShareImage) { share in
            ActivityViewController(image: share.image, title: share.title)
        }
    }

    // MARK: - Summary Section

    /// Aggregate statistics shown at the top of the screen.
    private var summarySection: some View {
        GroupBox(String(localized: "Summary")) {
            VStack(spacing: 8) {
                statRow(
                    label: String(localized: "Entries"),
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
                if let delta = stats.truckAccuracyDelta {
                    let direction = delta >= 0
                        ? String(localized: "overestimates")
                        : String(localized: "underestimates")
                    let pct = String(format: "%.1f", abs(delta))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Your truck \(direction) MPG by \(pct)% on average"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .accessibilityLabel(
                                String(localized: "Vehicle-reported MPG accuracy: your truck \(direction) MPG by \(pct) percent on average")
                            )
                        Text(stats.truckAccuracySampleCount == 1
                            ? String(localized: "Based on 1 entry")
                            : String(localized: "Based on \(stats.truckAccuracySampleCount) entries")
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
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
                .disabled(!showCalculatedMPG && !(stats.hasTruckReportedMPG && showVehicleReportedMPG))
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

    /// Year-over-year MPG comparison chart. Only shown when the current year has at least two entries.
    @ViewBuilder
    private var yoyChartSection: some View {
        if stats.currentYearPoints.count >= 2 {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        legendDot(color: .accentColor, opacity: 1.0, label: "\(stats.yoyCurrentYear)")
                        if !stats.priorYearPoints.isEmpty {
                            legendDot(color: .gray, opacity: 1.0, label: "\(stats.yoyCurrentYear - 1)")
                        }
                    }
                    yoyChartView
                        .accessibilityChartDescriptor(
                            YearOverYearChartDescriptor(
                                currentYearPoints: stats.currentYearPoints,
                                priorYearPoints: stats.priorYearPoints
                            )
                        )
                    Button {
                        if let image = renderImage(from: yoyChartView) {
                            yoyShareImage = ChartShareImage(
                                image: image,
                                title: String(localized: "Year-Over-Year MPG")
                            )
                        }
                    } label: {
                        Label(
                            String(localized: "Share Year-Over-Year Chart"),
                            systemImage: "square.and.arrow.up"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(String(localized: "Share year-over-year MPG chart"))
                    .accessibilityHint(String(localized: "Exports the chart as an image you can share"))
                }
            } label: {
                Text(String(localized: "Year-Over-Year MPG"))
                    .font(.headline)
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
                    ForEach(stats.chronologicalEntries.filter { ($0.truckReportedMPG ?? 0) > 0 }) { entry in
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

    /// The year-over-year MPG line chart — extracted for use with `ImageRenderer`.
    ///
    /// Current-year entries are drawn at full opacity; prior-year entries at 0.35 opacity.
    /// The x-axis always spans Jan 1 – Dec 31 of the current year so both series share the same scale.
    @ViewBuilder
    private var yoyChartView: some View {
        let cal = Calendar.current
        let yearStart = cal.date(from: DateComponents(year: stats.yoyCurrentYear, month: 1, day: 1))!
        let yearEnd = cal.date(from: DateComponents(year: stats.yoyCurrentYear, month: 12, day: 31))!
        let currentLabel = "\(stats.yoyCurrentYear)"
        let priorLabel = "\(stats.yoyCurrentYear - 1)"
        Chart {
            if !stats.priorYearPoints.isEmpty {
                ForEach(stats.priorYearPoints) { point in
                    LineMark(
                        x: .value(String(localized: "Month"), point.displayDate),
                        y: .value(String(localized: "MPG"), point.mpg)
                    )
                    .foregroundStyle(by: .value(String(localized: "Year"), point.yearLabel))
                    .interpolationMethod(.catmullRom)
                }
            }
            ForEach(stats.currentYearPoints) { point in
                LineMark(
                    x: .value(String(localized: "Month"), point.displayDate),
                    y: .value(String(localized: "MPG"), point.mpg)
                )
                .foregroundStyle(by: .value(String(localized: "Year"), point.yearLabel))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([currentLabel: Color.accentColor, priorLabel: Color.gray])
        .chartLegend(.hidden)
        .chartXScale(domain: yearStart...yearEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 200)
        .accessibilityLabel(String(localized: "Year-over-year MPG comparison line chart"))
    }

    // MARK: - Helpers

    /// A small colored dot paired with a text label, used in the year-over-year chart legend.
    private func legendDot(color: Color, opacity: Double, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

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
    ///
    /// Uses `chartExportWidth` — captured from the live layout via `onGeometryChange` —
    /// so `ImageRenderer` produces a full-width image without relying on `UIScreen`.
    private func renderImage<V: View>(from view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: chartExportWidth))
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

// MARK: - YearOverYearPoint

/// A single data point for the year-over-year MPG chart.
///
/// Prior-year dates are shifted to the current calendar year so both series share the same x-axis.
private struct YearOverYearPoint: Identifiable {
    /// Stable identifier required by `ForEach`.
    let id = UUID()
    /// The date used for chart plotting. Prior-year dates are shifted to the current year.
    let displayDate: Date
    /// The calculated MPG for this fill-up.
    let mpg: Double
    /// The calendar year string (e.g. "2025" or "2024") used in the chart legend.
    let yearLabel: String
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
        let priceEntries = entries.filter { ($0.pricePerGallon ?? 0) > 0 }
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

/// VoiceOver audio graph descriptor for the year-over-year MPG comparison chart.
private struct YearOverYearChartDescriptor: AXChartDescriptorRepresentable {

    /// Current-year data points in chronological order.
    let currentYearPoints: [YearOverYearPoint]
    /// Prior-year data points (shifted to current year) in chronological order.
    let priorYearPoints: [YearOverYearPoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let allMPG = (currentYearPoints + priorYearPoints).map(\.mpg)
        let minMPG = allMPG.min() ?? 0
        let maxMPG = max(allMPG.max() ?? 1, minMPG + 1)

        let allDates = (currentYearPoints + priorYearPoints)
            .map { $0.displayDate.formatted(date: .abbreviated, time: .omitted) }

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Month"),
            categoryOrder: allDates
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "MPG"),
            range: minMPG...maxMPG,
            gridlinePositions: []
        ) { value in String(format: "%.1f MPG", value) }

        var series: [AXDataSeriesDescriptor] = [
            AXDataSeriesDescriptor(
                name: currentYearPoints.first?.yearLabel ?? String(localized: "Current Year"),
                isContinuous: true,
                dataPoints: currentYearPoints.map { point in
                    AXDataPoint(
                        x: point.displayDate.formatted(date: .abbreviated, time: .omitted),
                        y: point.mpg,
                        label: String(format: "%.2f MPG", point.mpg)
                    )
                }
            )
        ]
        if !priorYearPoints.isEmpty {
            series.append(
                AXDataSeriesDescriptor(
                    name: priorYearPoints.first?.yearLabel ?? String(localized: "Prior Year"),
                    isContinuous: true,
                    dataPoints: priorYearPoints.map { point in
                        AXDataPoint(
                            x: point.displayDate.formatted(date: .abbreviated, time: .omitted),
                            y: point.mpg,
                            label: String(format: "%.2f MPG", point.mpg)
                        )
                    }
                )
            )
        }
        return AXChartDescriptor(
            title: String(localized: "Year-over-year MPG comparison"),
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
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

    /// Average percent delta of vehicle-reported MPG vs calculated MPG.
    /// Positive = vehicle overestimates; negative = underestimates. `nil` if no qualifying entries.
    let truckAccuracyDelta: Double?

    /// Number of entries that contributed to `truckAccuracyDelta`.
    let truckAccuracySampleCount: Int

    /// Entries sorted oldest-first for chronological chart display.
    let chronologicalEntries: [FillUpEntry]

    /// Chronological entries that have price-per-gallon data, for the fuel cost chart.
    let priceDataEntries: [FillUpEntry]

    /// Data points for the current calendar year, used by the year-over-year chart.
    let currentYearPoints: [YearOverYearPoint]

    /// Data points for the prior calendar year, shifted to the current year's date range for axis alignment.
    let priorYearPoints: [YearOverYearPoint]

    /// The current calendar year integer, used to build the Jan–Dec x-axis domain in the view.
    let yoyCurrentYear: Int

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
        hasPriceData = entries.contains { ($0.pricePerGallon ?? 0) > 0 }
        hasTruckReportedMPG = entries.contains { ($0.truckReportedMPG ?? 0) > 0 }

        let reportedPairs = entries.filter { ($0.truckReportedMPG ?? 0) > 0 && $0.calculatedMPG > 0 }
        truckAccuracySampleCount = reportedPairs.count
        if reportedPairs.isEmpty {
            truckAccuracyDelta = nil
        } else {
            let deltas = reportedPairs.map { ($0.truckReportedMPG! - $0.calculatedMPG) / $0.calculatedMPG * 100 }
            truckAccuracyDelta = deltas.reduce(0, +) / Double(deltas.count)
        }

        let sorted = entries.sorted { $0.date < $1.date }
        chronologicalEntries = sorted
        priceDataEntries = sorted.filter { ($0.pricePerGallon ?? 0) > 0 }

        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let priorYear = currentYear - 1
        yoyCurrentYear = currentYear
        let rawCurrent = sorted
            .filter { cal.component(.year, from: $0.date) == currentYear }
            .map { YearOverYearPoint(displayDate: $0.date, mpg: $0.calculatedMPG, yearLabel: "\(currentYear)") }
        let rawPrior = sorted
            .filter { cal.component(.year, from: $0.date) == priorYear }
            .map { entry in
                var comps = cal.dateComponents([.month, .day], from: entry.date)
                comps.year = currentYear
                let shifted = cal.date(from: comps) ?? entry.date
                return YearOverYearPoint(displayDate: shifted, mpg: entry.calculatedMPG, yearLabel: "\(priorYear)")
            }
        currentYearPoints = StatsSnapshot.smoothed(rawCurrent, windowDays: StatsSnapshot.yoySmoothingWindowDays)
        priorYearPoints = StatsSnapshot.smoothed(rawPrior, windowDays: StatsSnapshot.yoySmoothingWindowDays)
    }

    /// Number of days per smoothing bucket for the year-over-year chart.
    /// Change this value to adjust the smoothing granularity (e.g. 3, 5, 15, 30).
    static let yoySmoothingWindowDays = 5

    /// Buckets `points` into `windowDays`-day intervals and returns one averaged point per bucket.
    ///
    /// Points within each window are averaged by MPG; the median point's date is used as the
    /// representative display date. If `windowDays` is 1 or fewer, the original points are returned.
    private static func smoothed(_ points: [YearOverYearPoint], windowDays: Int) -> [YearOverYearPoint] {
        guard windowDays > 1, !points.isEmpty else { return points }
        let cal = Calendar.current
        var buckets: [Int: [YearOverYearPoint]] = [:]
        for point in points {
            let day = cal.ordinality(of: .day, in: .year, for: point.displayDate) ?? 1
            let bucket = (day - 1) / windowDays
            buckets[bucket, default: []].append(point)
        }
        return buckets.keys.sorted().map { key in
            let group = buckets[key]!
            let avgMPG = group.map(\.mpg).reduce(0, +) / Double(group.count)
            let midDate = group[group.count / 2].displayDate
            return YearOverYearPoint(displayDate: midDate, mpg: avgMPG, yearLabel: group[0].yearLabel)
        }
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
