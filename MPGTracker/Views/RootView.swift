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
        // Minimize-on-scroll-down gives the long History and Stats lists the
        // full screen height and lets content pass under the glass tab bar.
        TabView {
            historyTab
            addEntryTab
            statsTab
            settingsTab
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: - Tabs

    /// History tab — scrollable log of past fill-up sessions.
    private var historyTab: some TabContent<Never> {
        Tab(
            String(localized: "History"),
            systemImage: "list.bullet"
        ) {
            NavigationStack {
                HistoryView()
            }
        }
    }

    /// Add Entry tab — primary action; styled with accent color to stand out.
    private var addEntryTab: some TabContent<Never> {
        Tab(
            String(localized: "Add Entry"),
            systemImage: "plus.circle.fill"
        ) {
            NavigationStack {
                AddEntryView()
            }
            .tint(.accentColor)
        }
    }

    /// Stats tab — summary statistics and charts.
    private var statsTab: some TabContent<Never> {
        Tab(
            String(localized: "Stats"),
            systemImage: "chart.line.uptrend.xyaxis"
        ) {
            NavigationStack {
                StatsView()
            }
        }
    }

    /// Settings tab — import/export controls and About section.
    private var settingsTab: some TabContent<Never> {
        Tab(
            String(localized: "Settings"),
            systemImage: "gearshape"
        ) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView()
}
