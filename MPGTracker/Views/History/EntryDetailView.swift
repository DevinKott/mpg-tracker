//
//  EntryDetailView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI
import SwiftData

/// Shows all fields for a single fill-up entry.
///
/// Clearly distinguishes app-calculated values from user-entered data.
/// Provides toolbar actions for editing and deleting the entry.
struct EntryDetailView: View {

    @Bindable var entry: FillUpEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            calculatedSection
            inputsSection
            dateSection
            deleteSection
        }
        .navigationTitle(String(localized: "Fill-Up Detail"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "Edit")) { isEditing = true }
                    .accessibilityLabel(String(localized: "Edit this fill-up entry"))
            }
        }
        .sheet(isPresented: $isEditing) {
            EditEntrySheetView(entry: entry)
        }
        .alert(
            String(localized: "Delete this fill-up?"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
    }

    // MARK: - Sections

    /// App-calculated values: MPG and price per gallon (if available).
    private var calculatedSection: some View {
        Section(String(localized: "App-Calculated")) {
            detailRow(label: String(localized: "MPG"), value: String(format: "%.2f", entry.calculatedMPG), unit: String(localized: "mpg"))
            if let ppg = entry.pricePerGallon {
                detailRow(label: String(localized: "Price per gallon"), value: String(format: "$%.3f", ppg))
            }
        }
    }

    /// Values entered by the user at the pump.
    private var inputsSection: some View {
        Section(String(localized: "You Entered")) {
            detailRow(label: String(localized: "Miles driven"), value: String(format: "%.1f", entry.milesDriven), unit: String(localized: "mi"))
            detailRow(label: String(localized: "Gallons pumped"), value: String(format: "%.3f", entry.gallonsPumped), unit: String(localized: "gal"))
            if let total = entry.totalPricePaid {
                detailRow(label: String(localized: "Total price paid"), value: String(format: "$%.2f", total))
            }
            if let truckMPG = entry.truckReportedMPG {
                detailRow(label: String(localized: "Vehicle-reported MPG"), value: String(format: "%.1f", truckMPG))
            }
            if let notes = entry.notes {
                detailRow(label: String(localized: "Notes"), value: notes)
            }
        }
    }

    /// The date and time this fill-up was recorded. Read-only; edit via the Edit sheet.
    private var dateSection: some View {
        Section(String(localized: "Date")) {
            detailRow(
                label: String(localized: "Recorded"),
                value: entry.date.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }

    /// Destructive delete action for this entry.
    private var deleteSection: some View {
        Section {
            Button(String(localized: "Delete Entry"), role: .destructive) {
                showDeleteConfirmation = true
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(String(localized: "Delete this fill-up entry"))
            .accessibilityHint(String(localized: "Opens a confirmation before deleting"))
        }
    }

    // MARK: - Helpers

    /// A label–value row with an optional trailing unit suffix and combined accessibility support.
    private func detailRow(label: String, value: String, unit: String? = nil) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit.map { " \($0)" } ?? "")")
    }
}

// MARK: - Edit Sheet

/// Sheet view for editing an existing fill-up entry in place.
///
/// Pre-populates text fields from the entry's current values. On save, writes
/// updated values directly to the `@Bindable` entry — SwiftData auto-persists.
private struct EditEntrySheetView: View {

    @Bindable var entry: FillUpEntry
    @Environment(\.dismiss) private var dismiss

    @State private var milesText: String
    @State private var gallonsText: String
    @State private var totalPriceText: String
    @State private var truckMPGText: String
    @State private var notesText: String
    @State private var selectedDate: Date

    init(entry: FillUpEntry) {
        self.entry = entry
        _milesText = State(initialValue: String(entry.milesDriven))
        _gallonsText = State(initialValue: String(entry.gallonsPumped))
        _totalPriceText = State(initialValue: entry.totalPricePaid.map { String($0) } ?? "")
        _truckMPGText = State(initialValue: entry.truckReportedMPG.map { String($0) } ?? "")
        _notesText = State(initialValue: entry.notes ?? "")
        _selectedDate = State(initialValue: entry.date)
    }

    /// `true` when the parsed miles value exceeds the allowed maximum.
    private var milesExceedsMax: Bool { (parsedMiles ?? 0) > 1000 }

    /// `true` when the parsed gallons value exceeds the allowed maximum.
    private var gallonsExceedsMax: Bool { (parsedGallons ?? 0) > 100 }

    /// `true` when the required fields contain valid, in-range, non-zero values.
    private var isSaveEnabled: Bool {
        parsedMiles != nil && parsedGallons != nil && !milesExceedsMax && !gallonsExceedsMax
    }

    private var parsedMiles: Double? {
        guard let v = Double(milesText.trimmingCharacters(in: .whitespaces)), v > 0 else { return nil }
        return v
    }

    private var parsedGallons: Double? {
        guard let v = Double(gallonsText.trimmingCharacters(in: .whitespaces)), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                requiredSection
                optionalSection
            }
            .navigationTitle(String(localized: "Edit Fill-Up"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .accessibilityLabel(String(localized: "Cancel editing"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { applyChanges() }
                        .disabled(!isSaveEnabled)
                        .accessibilityLabel(
                            isSaveEnabled
                                ? String(localized: "Save changes")
                                : String(localized: "Save changes — enter miles and gallons first")
                        )
                }
            }
        }
    }

    // MARK: - Form sections

    /// Required fields: miles driven, gallons pumped, and fill-up date/time.
    private var requiredSection: some View {
        Section(String(localized: "Required")) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(localized: "Miles driven"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", text: $milesText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .onChange(of: milesText) { _, new in milesText = filterNumeric(new) }
                    Text(String(localized: "mi"))
                        .foregroundStyle(.secondary)
                }
                if milesExceedsMax {
                    Text(String(localized: "Max 1,000 mi"))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "Error: miles driven exceeds the maximum of 1,000"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Miles driven"))
            .accessibilityHint(String(localized: "Read from the vehicle's trip odometer"))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(localized: "Gallons pumped"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", text: $gallonsText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .onChange(of: gallonsText) { _, new in gallonsText = filterNumeric(new) }
                    Text(String(localized: "gal"))
                        .foregroundStyle(.secondary)
                }
                if gallonsExceedsMax {
                    Text(String(localized: "Max 100 gal"))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "Error: gallons pumped exceeds the maximum of 100"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Gallons pumped"))
            .accessibilityHint(String(localized: "Read from the fuel pump display"))

            DatePicker(
                String(localized: "Date & Time"),
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel(String(localized: "Fill-up date and time"))
            .accessibilityHint(String(localized: "The date and time this fill-up occurred"))
        }
    }

    /// Optional fields: total price, vehicle-reported MPG, notes.
    private var optionalSection: some View {
        Section(String(localized: "Optional")) {
            HStack {
                Text(String(localized: "Total price paid"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("", text: $totalPriceText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .onChange(of: totalPriceText) { _, new in totalPriceText = filterNumeric(new) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Total price paid"))
            .accessibilityHint(String(localized: "Total dollar amount at the pump"))

            HStack {
                Text(String(localized: "Vehicle MPG"))
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", text: $truckMPGText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .onChange(of: truckMPGText) { _, new in truckMPGText = filterNumeric(new) }
                Text(String(localized: "mpg"))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Vehicle-reported MPG"))
            .accessibilityHint(String(localized: "MPG shown on the vehicle's dashboard computer"))

            TextField(String(localized: "Notes"), text: $notesText)
                .accessibilityLabel(String(localized: "Notes"))
                .accessibilityHint(String(localized: "Optional free-text note about this fill-up"))
        }
    }

    // MARK: - Actions

    /// Writes the parsed field values back to the entry and dismisses the sheet.
    ///
    /// Derived values (`calculatedMPG`, `pricePerGallon`) are recalculated
    /// explicitly here because SwiftData `@Model` accessors do not reliably
    /// trigger `didSet` observers when properties are mutated externally.
    private func applyChanges() {
        guard let miles = parsedMiles, let gallons = parsedGallons else { return }
        let totalPrice = Double(totalPriceText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        entry.date = selectedDate
        entry.milesDriven = miles
        entry.gallonsPumped = gallons
        entry.calculatedMPG = MPGCalculator.calculateMPG(miles: miles, gallons: gallons)
        entry.totalPricePaid = totalPrice
        entry.pricePerGallon = totalPrice.flatMap { gallons > 0 ? MPGCalculator.calculatePricePerGallon(totalPrice: $0, gallons: gallons) : nil }
        entry.truckReportedMPG = Double(truckMPGText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        dismiss()
    }

    /// Strips any character that is not a digit or decimal point.
    private func filterNumeric(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "." }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    let entry = FillUpEntry(
        date: Date(),
        milesDriven: 312.5,
        gallonsPumped: 12.8,
        totalPricePaid: 45.60,
        truckReportedMPG: 24.1,
        notes: "Highway trip"
    )
    container.mainContext.insert(entry)
    return NavigationStack {
        EntryDetailView(entry: entry)
    }
    .modelContainer(container)
}
