//
//  SettingsView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/3/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Settings screen. Provides data import/export controls and an About section.
struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FillUpEntry]

    @State private var isImporting = false
    @State private var shareURL: ShareURL? = nil
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var didImport = false
    @State private var importedCount = 0

    var body: some View {
        Form {
            dataSection
            aboutSection
        }
        .navigationTitle(String(localized: "Settings"))
        .overlay(alignment: .top) {
            if didImport { importBanner }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(item: $shareURL) { share in
            ActivityViewController(items: [share.url])
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Sections

    /// Controls for exporting all data and importing from a CSV file.
    private var dataSection: some View {
        Section(String(localized: "Data")) {
            Button(String(localized: "Export as CSV")) {
                exportCSV()
            }
            .accessibilityLabel(String(localized: "Export as CSV"))
            .accessibilityHint(String(localized: "Generates a CSV file of all your entries and opens a share sheet"))

            Button(String(localized: "Import from CSV")) {
                isImporting = true
            }
            .accessibilityLabel(String(localized: "Import from CSV"))
            .accessibilityHint(String(localized: "Opens a file picker so you can select a previously exported CSV file"))
        }
    }

    /// App info, purpose, privacy statement, and developer credit.
    private var aboutSection: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return Section(String(localized: "About")) {
            Text("Fuel Efficiency Tracker \(version)")
                .accessibilityLabel(String(localized: "Fuel Efficiency Tracker, version \(version)"))

            Text(String(localized: "A personal tool I built for tracking fuel efficiency."))
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "A personal tool I built for tracking fuel efficiency."))

            Text(String(localized: "No data collected. No ads. No subscriptions. Data stays on your device."))
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "No data collected. No ads. No subscriptions. Data stays on your device."))

            Text(String(localized: "Made by Devin Kott"))
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "Made by Devin Kott"))
        }
    }

    // MARK: - Banner

    /// Brief confirmation shown after a clean (0 skipped) import.
    private var importBanner: some View {
        let label = importedCount == 1
            ? String(localized: "Imported 1 entry")
            : String(localized: "Imported \(importedCount) entries")
        return Text(label)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(label)
    }

    /// Displays the import banner briefly with the given entry count, then hides it.
    private func showImportConfirmation(count: Int) {
        importedCount = count
        withAnimation { didImport = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { didImport = false }
        }
    }

    // MARK: - Export

    /// Generates a CSV string on the main thread, then writes the temp file on a background thread.
    ///
    /// `DataTransfer.exportCSV` takes `[FillUpEntry]` (`@MainActor`-bound), so string generation
    /// must stay on main. Only the disk write is offloaded.
    private func exportCSV() {
        let csv = DataTransfer.exportCSV(entries: entries)
        guard let data = csv.data(using: .utf8) else {
            alertTitle = String(localized: "Export Error")
            alertMessage = String(localized: "Export failed. Please try again.")
            showAlert = true
            return
        }
        Task.detached(priority: .userInitiated) {
            guard let url = writeTempFile(name: "mpgtracker_export.csv", data: data) else {
                await MainActor.run {
                    alertTitle = String(localized: "Export Error")
                    alertMessage = String(localized: "Export failed. Please try again.")
                    showAlert = true
                }
                return
            }
            await MainActor.run { shareURL = ShareURL(url: url) }
        }
    }

    /// Generates JSON data on the main thread, then writes the temp file on a background thread.
    private func exportJSON() {
        guard let data = try? DataTransfer.exportJSON(entries: entries) else { return }
        Task.detached(priority: .userInitiated) {
            guard let url = writeTempFile(name: "mpgtracker_export.json", data: data) else { return }
            await MainActor.run { shareURL = ShareURL(url: url) }
        }
    }

    /// Writes `data` to a temp file and returns its URL. Returns `nil` on failure.
    ///
    /// Marked `nonisolated` — accesses no instance state, safe to call from any thread.
    private nonisolated func writeTempFile(name: String, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Import

    /// Reads the selected CSV file, parses it, and inserts valid entries into the model context.
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure:
            alertTitle = String(localized: "Import Error")
            alertMessage = String(localized: "Could not open the selected file.")
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            importEntries(from: url)
        }
    }

    /// Reads the CSV file on a background thread, then parses and inserts entries on the main thread.
    private func importEntries(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) {
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let csv = try? String(contentsOf: url, encoding: .utf8) else {
                await MainActor.run {
                    alertTitle = String(localized: "Import Error")
                    alertMessage = String(localized: "Could not read the selected file.")
                    showAlert = true
                }
                return
            }
            await MainActor.run {
                parseAndInsert(csv: csv)
            }
        }
    }

    /// Parses a CSV string and inserts valid entries into the model context.
    private func parseAndInsert(csv: String) {
        let result: (entries: [FillUpEntry], skippedCount: Int)
        do {
            result = try DataTransfer.importCSV(csv)
        } catch let error as DataTransfer.ImportError {
            alertTitle = String(localized: "Import Error")
            alertMessage = error.errorDescription ?? String(localized: "The file could not be imported.")
            showAlert = true
            return
        } catch {
            alertTitle = String(localized: "Import Error")
            alertMessage = String(localized: "The file could not be imported.")
            showAlert = true
            return
        }

        guard !result.entries.isEmpty else {
            alertTitle = String(localized: "Import Error")
            alertMessage = String(localized: "No valid entries were found in the file.")
            showAlert = true
            return
        }

        for entry in result.entries {
            modelContext.insert(entry)
        }

        if result.skippedCount == 0 {
            showImportConfirmation(count: result.entries.count)
        } else {
            let imported = result.entries.count
            let skipped = result.skippedCount
            let importedLine = imported == 1
                ? String(localized: "Imported 1 entry.")
                : String(localized: "Imported \(imported) entries.")
            let skippedLine = skipped == 1
                ? String(localized: "1 row was skipped due to formatting errors.")
                : String(localized: "\(skipped) rows were skipped due to formatting errors.")
            alertTitle = String(localized: "Import Successful")
            alertMessage = "\(importedLine) \(skippedLine)"
            showAlert = true
        }
    }
}

// MARK: - ShareURL

/// An `Identifiable` wrapper around a `URL`, used to drive `.sheet(item:)` for share-sheet presentation.
private struct ShareURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ActivityViewController

/// A thin UIKit bridge that presents a `UIActivityViewController` for sharing arbitrary items.
private struct ActivityViewController: UIViewControllerRepresentable {

    /// The items to share (e.g., file URLs or plain text).
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FillUpEntry.self, configurations: config)
    return NavigationStack {
        SettingsView()
    }
    .modelContainer(container)
}
