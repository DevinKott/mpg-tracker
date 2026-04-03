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
/// Supports swipe-to-delete and tap-to-navigate for each entry.
/// Shows an empty-state prompt when no entries have been saved.
struct HistoryView: View {

    @Query(sort: \FillUpEntry.date, order: .reverse) private var entries: [FillUpEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if entries.isEmpty {
            emptyStateView
        } else {
            entryList
        }
    }

    // MARK: - Subviews

    /// Prompt shown when no entries have been saved yet.
    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Fill-Ups Yet"),
            systemImage: "fuelpump",
            description: Text(String(localized: "Tap Add Entry to record your first fill-up."))
        )
        .navigationTitle(String(localized: "History"))
        .accessibilityLabel(String(localized: "No fill-up entries. Tap Add Entry to get started."))
    }

    /// Scrollable list of all fill-up entries.
    private var entryList: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    FillUpEntryRow(entry: entry)
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle(String(localized: "History"))
        .navigationDestination(for: FillUpEntry.self) { entry in
            EntryDetailView(entry: entry)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .accessibilityLabel(String(localized: "Toggle edit mode"))
            }
        }
    }

    // MARK: - Actions

    /// Deletes entries at the given index set from the model context.
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
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
    ctx.insert(FillUpEntry(date: Date().addingTimeInterval(-86400 * 14), milesDriven: 280.0, gallonsPumped: 11.5, notes: "Highway trip"))
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
