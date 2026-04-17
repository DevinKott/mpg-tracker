//
//  HistoryView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI
import SwiftData

/// Displays all fill-up entries in reverse chronological order.
///
/// Supports swipe-to-delete, multi-select delete, and tap-to-navigate for each entry.
/// Shows an empty-state prompt when no entries have been saved.
struct HistoryView: View {

    @Query(sort: \FillUpEntry.date, order: .reverse) private var entries: [FillUpEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        if entries.isEmpty {
            emptyStateView
        } else {
            entryList
        }
    }

    // MARK: - Grouping

    /// Entries grouped by calendar month, newest section first.
    ///
    /// Each element is a `(key: String, entries: [FillUpEntry])` pair where
    /// `key` is the formatted month/year label (e.g. "April 2026") and
    /// `entries` is that month's fill-ups in reverse-chronological order.
    private var groupedEntries: [(key: String, entries: [FillUpEntry])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var dict: [DateComponents: [FillUpEntry]] = [:]
        for entry in entries {
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            dict[comps, default: []].append(entry)
        }

        return dict
            .sorted { lhs, rhs in
                guard let ly = lhs.key.year, let lm = lhs.key.month,
                      let ry = rhs.key.year, let rm = rhs.key.month else { return false }
                return ly == ry ? lm > rm : ly > ry
            }
            .map { comps, sectionEntries in
                let title = sectionEntries.first.map { formatter.string(from: $0.date) } ?? ""
                let sorted = sectionEntries.sorted { $0.date > $1.date }
                return (key: title, entries: sorted)
            }
    }

    // MARK: - Subviews

    /// Prompt shown when no entries have been saved yet.
    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Entries Yet"),
            systemImage: "fuelpump",
            description: Text(String(localized: "Tap Add Entry to record your first entry."))
        )
        .navigationTitle(String(localized: "History"))
        .accessibilityLabel(String(localized: "No entries. Tap Add Entry to get started."))
    }

    /// Scrollable list of all fill-up entries grouped by month, with multi-select support.
    private var entryList: some View {
        List(selection: $selection) {
            ForEach(groupedEntries, id: \.key) { section in
                Section(header: Text(section.key)) {
                    ForEach(section.entries) { entry in
                        NavigationLink(value: entry) {
                            FillUpEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in
                        deleteEntries(inSection: section.key, at: offsets)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(String(localized: "History"))
        .navigationDestination(for: FillUpEntry.self) { entry in
            EntryDetailView(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if editMode.isEditing {
                    selectAllButton
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if editMode.isEditing {
                    deleteSelectedButton
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                editDoneButton
            }
        }
        .alert(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                deleteSelected()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
    }

    // MARK: - Toolbar Items

    /// Toggles between "Select All" and "Deselect All" depending on current selection.
    private var selectAllButton: some View {
        let allSelected = selection.count == entries.count
        return Button(allSelected ? String(localized: "Deselect All") : String(localized: "Select All")) {
            selection = allSelected ? [] : Set(entries.map(\.id))
        }
        .accessibilityLabel(allSelected ? String(localized: "Deselect All") : String(localized: "Select All"))
        .accessibilityHint(
            allSelected
                ? String(localized: "Deselects all entries")
                : String(localized: "Selects all entries")
        )
    }

    /// Delete button, disabled when nothing is selected.
    private var deleteSelectedButton: some View {
        Button(String(localized: "Delete (\(selection.count))"), role: .destructive) {
            showDeleteConfirmation = true
        }
        .disabled(selection.isEmpty)
        .accessibilityLabel(String(localized: "Delete selected entries"))
        .accessibilityHint(
            String(localized: "Deletes \(selection.count) selected entries. This cannot be undone.")
        )
    }

    /// Toggles between "Edit" and "Done".
    private var editDoneButton: some View {
        Button(editMode.isEditing ? String(localized: "Done") : String(localized: "Edit")) {
            editMode = editMode.isEditing ? .inactive : .active
            if !editMode.isEditing { selection = [] }
        }
        .accessibilityLabel(editMode.isEditing ? String(localized: "Done editing") : String(localized: "Edit entries"))
        .accessibilityHint(
            editMode.isEditing
                ? String(localized: "Exits selection mode")
                : String(localized: "Enters selection mode for bulk deletion")
        )
    }

    // MARK: - Actions

    /// Confirmation dialog title showing how many entries will be deleted.
    private var deleteConfirmationTitle: String {
        selection.count == 1
            ? String(localized: "Delete 1 entry? This cannot be undone.")
            : String(localized: "Delete \(selection.count) entries? This cannot be undone.")
    }

    /// Deletes selected entries and exits edit mode.
    private func deleteSelected() {
        let toDelete = entries.filter { selection.contains($0.id) }
        for entry in toDelete {
            modelContext.delete(entry)
        }
        selection = []
        editMode = .inactive
    }

    /// Deletes entries at section-local offsets (swipe-to-delete).
    private func deleteEntries(inSection key: String, at offsets: IndexSet) {
        guard let section = groupedEntries.first(where: { $0.key == key }) else { return }
        for index in offsets {
            modelContext.delete(section.entries[index])
        }
    }
}

// MARK: - Row View

/// A single row in the history list showing the key details of a fill-up.
private struct FillUpEntryRow: View {

    let entry: FillUpEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f MPG", entry.calculatedMPG))
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.3f gal", entry.gallonsPumped))
                    .font(.subheadline)
                if let ppg = entry.pricePerGallon {
                    Text(String(format: "$%.3f/gal", ppg))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    /// Combined accessibility label describing the entry for VoiceOver.
    private var rowAccessibilityLabel: String {
        var parts = [
            entry.date.formatted(date: .long, time: .omitted),
            String(format: "%.2f miles per gallon", entry.calculatedMPG),
            String(format: "%.3f gallons", entry.gallonsPumped)
        ]
        if let ppg = entry.pricePerGallon {
            parts.append(String(format: "$%.3f per gallon", ppg))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("With entries") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    let ctx = container.mainContext
    ctx.insert(FillUpEntry(date: Date(), milesDriven: 312.5, gallonsPumped: 12.8, totalPricePaid: 45.60, truckReportedMPG: 24.1))
    ctx.insert(FillUpEntry(date: Date().addingTimeInterval(-86400 * 45), milesDriven: 280.0, gallonsPumped: 11.5, notes: "Highway trip"))
    return NavigationStack {
        HistoryView()
    }
    .modelContainer(container)
}

#Preview("Empty state") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    return NavigationStack {
        HistoryView()
    }
    .modelContainer(container)
}
