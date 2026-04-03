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

    // MARK: - Price-per-gallon override state

    /// Raw text for the manual price-per-gallon override.
    @State private var priceOverrideText: String = ""
    /// Whether the user has switched to manual price-per-gallon entry.
    @State private var isPriceOverridden: Bool = false

    // MARK: - UI state

    /// The date and time of this fill-up, defaulting to now.
    @State private var entryDate: Date = Date()
    /// Triggers the post-save confirmation banner.
    @State private var didSave: Bool = false

    // MARK: - Body

    var body: some View {
        Form {
            requiredFieldsSection
            liveCalculatedMPGRow
            optionalFieldsSection
            saveSection
        }
        .navigationTitle(String(localized: "Add Fill-Up"))
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

    /// The price-per-gallon value to persist: the user's override if active, else auto-calculated.
    private var effectivePricePerGallon: Double? {
        if isPriceOverridden {
            return Double(priceOverrideText.trimmingCharacters(in: .whitespaces))
        }
        return liveCalculatedPricePerGallon
    }

    /// `true` when the required fields contain valid, non-zero values.
    private var isSaveEnabled: Bool {
        parsedMiles != nil && parsedGallons != nil
    }

    // MARK: - Form sections

    /// Required fields: miles driven and gallons pumped.
    private var requiredFieldsSection: some View {
        Section(String(localized: "Required")) {
            TextField(
                String(localized: "Miles driven"),
                text: $milesText
            )
            .keyboardType(.decimalPad)
            .onChange(of: milesText) { _, new in milesText = filterNumeric(new) }
            .accessibilityLabel(String(localized: "Miles driven"))
            .accessibilityHint(String(localized: "Read from the vehicle's trip odometer"))

            TextField(
                String(localized: "Gallons pumped"),
                text: $gallonsText
            )
            .keyboardType(.decimalPad)
            .onChange(of: gallonsText) { _, new in gallonsText = filterNumeric(new) }
            .accessibilityLabel(String(localized: "Gallons pumped"))
            .accessibilityHint(String(localized: "Read from the fuel pump display"))
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
            .accessibilityHint(String(localized: "Optional free-text note about this fill-up"))

            DatePicker(
                String(localized: "Date & Time"),
                selection: $entryDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityLabel(String(localized: "Fill-up date and time"))
            .accessibilityHint(String(localized: "Defaults to now; adjust if this fill-up happened earlier"))
        }
    }

    /// Price-per-gallon row: auto-calculated display by default; editable on override.
    @ViewBuilder
    private var pricePerGallonRow: some View {
        if isPriceOverridden {
            HStack {
                TextField(
                    String(localized: "Price per gallon ($)"),
                    text: $priceOverrideText
                )
                .keyboardType(.decimalPad)
                .accessibilityLabel(String(localized: "Price per gallon (manual)"))
                .accessibilityHint(String(localized: "Your manually entered price per gallon"))

                Button(String(localized: "Use calculated")) {
                    isPriceOverridden = false
                    priceOverrideText = ""
                }
                .font(.caption)
                .accessibilityLabel(String(localized: "Switch to calculated price per gallon"))
            }
        } else {
            HStack {
                Text(String(localized: "Price per gallon"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(liveCalculatedPricePerGallon.map { String(format: "$%.3f", $0) } ?? "—")
                    .foregroundStyle(liveCalculatedPricePerGallon == nil ? .tertiary : .primary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                priceOverrideText = liveCalculatedPricePerGallon.map { String(format: "%.3f", $0) } ?? ""
                isPriceOverridden = true
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                liveCalculatedPricePerGallon.map { String(localized: "Price per gallon: \(String(format: "$%.3f", $0))") }
                ?? String(localized: "Price per gallon: not yet available")
            )
            .accessibilityHint(String(localized: "Tap to enter a manual price per gallon"))
            .accessibilityAddTraits(.isButton)
        }
    }

    /// Section containing the Save button.
    private var saveSection: some View {
        Section {
            Button(String(localized: "Save Fill-Up")) {
                saveEntry()
            }
            .disabled(!isSaveEnabled)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(
                isSaveEnabled
                    ? String(localized: "Save fill-up entry")
                    : String(localized: "Save fill-up entry — enter miles and gallons first")
            )
        }
    }

    /// Brief banner shown after a successful save.
    private var savedBanner: some View {
        Text(String(localized: "Fill-up saved"))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(String(localized: "Fill-up saved successfully"))
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

        if let override = effectivePricePerGallon, isPriceOverridden {
            entry.pricePerGallon = override
        }

        resetForm()
        showSaveConfirmation()
    }

    /// Clears all form fields back to their initial empty state.
    private func resetForm() {
        milesText = ""
        gallonsText = ""
        totalPriceText = ""
        truckMPGText = ""
        notes = ""
        priceOverrideText = ""
        isPriceOverridden = false
        entryDate = Date()
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
