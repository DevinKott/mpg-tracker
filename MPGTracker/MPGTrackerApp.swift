//
//  MPGTrackerApp.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import SwiftUI
import SwiftData

@main
struct MPGTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FillUpEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
