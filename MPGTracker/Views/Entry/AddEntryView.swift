//
//  AddEntryView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI
import SwiftData

/// The fill-up entry form. Allows the user to record a new fuel session.
///
/// Required fields are miles driven and gallons pumped. All other fields are
/// optional. Calculated values (MPG, price per gallon) update live as the user
/// types. On save the form resets; the entry is persisted via SwiftData.
struct AddEntryView: View {

    @Environment(\.modelContext) private var modelContext

    // MARK: - Types

    /// Identifies the focusable required input fields for dirty-state validation.
    private enum FormField { case miles, gallons }

    // MARK: - Required field state

    /// Raw text for the miles driven field.
    @State private var milesText: String = ""
    /// Raw text for the gallons pumped field.
    @State private var gallonsText: String = ""

    // MARK: - Optional field state

    /// Raw text for the total price paid field.
    @State private var totalPriceText: String = ""
    /// Raw text for the vehicle-reported MPG field.
    @State private var truckMPGText: String = ""
    /// Free-text note for this fill-up.
    @State private var notes: String = ""

    // MARK: - UI state

    /// The date and time of this fill-up, defaulting to now.
    @State private var entryDate: Date = Date()
    /// Triggers the post-save confirmation banner.
    @State private var didSave: Bool = false
    /// Tracks which required field currently has keyboard focus.
    @FocusState private var focusedField: FormField?
    /// `true` once the miles field has lost focus at least once while empty.
    @State private var milesFieldTouched = false
    /// `true` once the gallons field has lost focus at least once while empty.
    @State private var gallonsFieldTouched = false

    // MARK: - Body

    var body: some View {
        Form {
            requiredFieldsSection
            liveCalculatedMPGRow
            optionalFieldsSection
            saveSection
        }
        .navigationTitle(String(localized: "Add Entry"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if focusedField != nil {
                    Button(String(localized: "Done")) {
                        focusedField = nil
                    }
                }
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                if oldValue == .miles { milesFieldTouched = true }
                if oldValue == .gallons { gallonsFieldTouched = true }
            }
        }
        .overlay(alignment: .top) {
            if didSave { savedBanner }
        }
    }

    // MARK: - Computed parsing properties

    /// Parsed miles value; `nil` if the text is empty, non-numeric, or zero.
    private var parsedMiles: Double? {
        guard let value = Double(milesText.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    /// Parsed gallons value; `nil` if the text is empty, non-numeric, or zero.
    private var parsedGallons: Double? {
        guard let value = Double(gallonsText.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    /// Live calculated MPG; `nil` when either required field is invalid.
    private var liveCalculatedMPG: Double? {
        guard let miles = parsedMiles, let gallons = parsedGallons else { return nil }
        return MPGCalculator.calculateMPG(miles: miles, gallons: gallons)
    }

    /// Live calculated price per gallon from total price and gallons; `nil` when either is invalid.
    private var liveCalculatedPricePerGallon: Double? {
        guard let gallons = parsedGallons,
              let total = Double(totalPriceText.trimmingCharacters(in: .whitespaces)),
              total > 0 else { return nil }
        return MPGCalculator.calculatePricePerGallon(totalPrice: total, gallons: gallons)
    }

    /// `true` when the parsed miles value exceeds the allowed maximum.
    private var milesExceedsMax: Bool { (parsedMiles ?? 0) > 1000 }

    /// `true` when the parsed gallons value exceeds the allowed maximum.
    private var gallonsExceedsMax: Bool { (parsedGallons ?? 0) > 100 }

    /// `true` when the required fields contain valid, in-range, non-zero values.
    private var isSaveEnabled: Bool {
        parsedMiles != nil && parsedGallons != nil && !milesExceedsMax && !gallonsExceedsMax
    }

    // MARK: - Form sections

    /// Required fields: miles driven and gallons pumped.
    private var requiredFieldsSection: some View {
        Section(String(localized: "Required")) {
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    String(localized: "Miles driven"),
                    text: $milesText
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .miles)
                .onChange(of: milesText) { _, new in milesText = filterNumeric(new) }
                .accessibilityLabel(String(localized: "Miles driven"))
                .accessibilityHint(String(localized: "Read from the vehicle's trip odometer"))

                if milesExceedsMax {
                    Text(String(localized: "Max 1,000 mi"))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "Error: miles driven exceeds the maximum of 1,000"))
                        .transition(.opacity)
                } else if milesFieldTouched && parsedMiles == nil {
                    Text(String(localized: "Required"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Miles driven is required"))
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: milesExceedsMax)

            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    String(localized: "Gallons pumped"),
                    text: $gallonsText
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .gallons)
                .onChange(of: gallonsText) { _, new in gallonsText = filterNumeric(new) }
                .accessibilityLabel(String(localized: "Gallons pumped"))
                .accessibilityHint(String(localized: "Read from the fuel pump display"))

                if gallonsExceedsMax {
                    Text(String(localized: "Max 100 gal"))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "Error: gallons pumped exceeds the maximum of 100"))
                        .transition(.opacity)
                } else if gallonsFieldTouched && parsedGallons == nil {
                    Text(String(localized: "Required"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Gallons pumped is required"))
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: gallonsExceedsMax)
        }
    }

    /// Read-only row showing live calculated MPG below the required fields.
    private var liveCalculatedMPGRow: some View {
        Section {
            HStack {
                Text(String(localized: "Calculated MPG"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(liveCalculatedMPG.map { String(format: "%.2f", $0) } ?? "—")
                    .foregroundStyle(liveCalculatedMPG == nil ? .tertiary : .primary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                liveCalculatedMPG.map { String(localized: "Calculated MPG: \(String(format: "%.2f", $0))") }
                ?? String(localized: "Calculated MPG: not yet available")
            )
        }
    }

    /// Optional fields: total price, price per gallon, vehicle-reported MPG, notes.
    private var optionalFieldsSection: some View {
        Section(String(localized: "Optional")) {
            TextField(
                String(localized: "Total price paid ($)"),
                text: $totalPriceText
            )
            .keyboardType(.decimalPad)
            .onChange(of: totalPriceText) { _, new in totalPriceText = filterNumeric(new) }
            .accessibilityLabel(String(localized: "Total price paid"))
            .accessibilityHint(String(localized: "Total dollar amount at the pump"))

            pricePerGallonRow

            TextField(
                String(localized: "Vehicle-reported MPG"),
                text: $truckMPGText
            )
            .keyboardType(.decimalPad)
            .onChange(of: truckMPGText) { _, new in truckMPGText = filterNumeric(new) }
            .accessibilityLabel(String(localized: "Vehicle-reported MPG"))
            .accessibilityHint(String(localized: "MPG shown on the vehicle's dashboard computer"))

            TextField(
                String(localized: "Notes"),
                text: $notes
            )
            .accessibilityLabel(String(localized: "Notes"))
            .accessibilityHint(String(localized: "Optional note for this entry"))

            DatePicker(
                String(localized: "Date & Time"),
                selection: $entryDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel(String(localized: "Entry date and time"))
            .accessibilityHint(String(localized: "Defaults to now; adjust if this entry happened earlier"))
        }
    }

    /// Read-only row showing live calculated price per gallon from total price and gallons.
    private var pricePerGallonRow: some View {
        HStack {
            Text(String(localized: "Price per gallon"))
                .foregroundStyle(.secondary)
            Spacer()
            Text(liveCalculatedPricePerGallon.map { String(format: "$%.3f", $0) } ?? "—")
                .foregroundStyle(liveCalculatedPricePerGallon == nil ? .tertiary : .primary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            liveCalculatedPricePerGallon.map { String(localized: "Price per gallon: \(String(format: "$%.3f", $0))") }
            ?? String(localized: "Price per gallon: not yet available")
        )
    }

    /// Section containing the Save button.
    private var saveSection: some View {
        Section {
            Button(String(localized: "Save Entry")) {
                saveEntry()
            }
            .disabled(!isSaveEnabled)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(
                isSaveEnabled
                    ? String(localized: "Save entry")
                    : String(localized: "Save entry — enter miles and gallons first")
            )
        }
    }

    /// Brief banner shown after a successful save.
    private var savedBanner: some View {
        Text(String(localized: "Entry saved"))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(String(localized: "Entry saved successfully"))
    }

    // MARK: - Helpers

    /// Strips any character that is not a digit or decimal point.
    private func filterNumeric(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "." }
    }

    // MARK: - Actions

    /// Creates a `FillUpEntry`, inserts it into the model context, and resets the form.
    private func saveEntry() {
        guard let miles = parsedMiles, let gallons = parsedGallons else { return }

        let totalPrice = Double(totalPriceText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        let truckMPG = Double(truckMPGText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        let notesTrimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let entry = FillUpEntry(
            date: entryDate,
            milesDriven: miles,
            gallonsPumped: gallons,
            totalPricePaid: totalPrice,
            truckReportedMPG: truckMPG,
            notes: notesTrimmed.isEmpty ? nil : notesTrimmed
        )

        modelContext.insert(entry)
        resetForm()
        showSaveConfirmation()
    }

    /// Clears all form fields back to their initial empty state.
    private func resetForm() {
        focusedField = nil
        milesText = ""
        gallonsText = ""
        totalPriceText = ""
        truckMPGText = ""
        notes = ""
        entryDate = Date()
        milesFieldTouched = false
        gallonsFieldTouched = false
    }

    /// Displays the saved banner briefly, then hides it.
    private func showSaveConfirmation() {
        withAnimation { didSave = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { didSave = false }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    return NavigationStack {
        AddEntryView()
    }
    .modelContainer(container)
}
