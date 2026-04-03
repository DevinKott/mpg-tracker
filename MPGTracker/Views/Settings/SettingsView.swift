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
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        Form {
            dataSection
            aboutSection
        }
        .navigationTitle(String(localized: "Settings"))
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewController(items: shareItems)
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
            .accessibilityHint(String(localized: "Generates a CSV file of all your fill-up entries and opens a share sheet"))

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

    // MARK: - Export

    /// Generates a CSV export and presents the share sheet.
    private func exportCSV() {
        let csv = DataTransfer.exportCSV(entries: entries)
        guard let data = csv.data(using: .utf8),
              let url = writeTempFile(name: "mpgtracker_export.csv", data: data) else { return }
        shareItems = [url]
        isShowingShareSheet = true
    }

    /// Generates a JSON export and presents the share sheet.
    private func exportJSON() {
        guard let data = try? DataTransfer.exportJSON(entries: entries),
              let url = writeTempFile(name: "mpgtracker_export.json", data: data) else { return }
        shareItems = [url]
        isShowingShareSheet = true
    }

    /// Writes `data` to a temp file and returns its URL. Returns `nil` on failure.
    private func writeTempFile(name: String, data: Data) -> URL? {
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

    /// Parses a CSV file at the given URL and inserts the resulting entries.
    private func importEntries(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let csv = try? String(contentsOf: url, encoding: .utf8) else {
            alertTitle = String(localized: "Import Error")
            alertMessage = String(localized: "Could not read the selected file.")
            showAlert = true
            return
        }

        let newEntries = DataTransfer.importCSV(csv)
        guard !newEntries.isEmpty else {
            alertTitle = String(localized: "Import Error")
            alertMessage = String(localized: "No valid fill-up entries were found in the file.")
            showAlert = true
            return
        }

        for entry in newEntries {
            modelContext.insert(entry)
        }

        let count = newEntries.count
        alertTitle = String(localized: "Import Successful")
        alertMessage = count == 1
            ? String(localized: "Successfully imported 1 fill-up.")
            : String(localized: "Successfully imported \(count) fill-ups.")
        showAlert = true
    }
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
