//
//  RootView.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI

/// The top-level shell view. Hosts all major screens via a `TabView`.
struct RootView: View {

    var body: some View {
        TabView {
            historyTab
            addEntryTab
            statsTab
            settingsTab
        }
    }

    // MARK: - Tabs

    /// History tab — scrollable log of past fill-up sessions.
    private var historyTab: some View {
        NavigationStack {
            HistoryView()
        }
        .tabItem {
            Label(
                String(localized: "History"),
                systemImage: "list.bullet"
            )
        }
    }

    /// Add Entry tab — primary action; styled with accent color to stand out.
    private var addEntryTab: some View {
        NavigationStack {
            AddEntryView()
        }
        .tabItem {
            Label(
                String(localized: "Add Entry"),
                systemImage: "plus.circle.fill"
            )
        }
        .tint(.accentColor)
    }

    /// Stats tab — summary statistics and charts.
    private var statsTab: some View {
        NavigationStack {
            StatsView()
        }
        .tabItem {
            Label(
                String(localized: "Stats"),
                systemImage: "chart.line.uptrend.xyaxis"
            )
        }
    }

    /// Settings tab — import/export controls and About section.
    private var settingsTab: some View {
        NavigationStack {
            Text(String(localized: "Settings"))
                .accessibilityLabel(String(localized: "Settings screen placeholder"))
        }
        .tabItem {
            Label(
                String(localized: "Settings"),
                systemImage: "gearshape"
            )
        }
    }
}

#Preview {
    RootView()
}
