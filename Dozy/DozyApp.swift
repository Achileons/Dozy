//
//  DozyApp.swift
//  Dozy
//
//  Created by Arda Agovic on 7.09.2026.
//

import SwiftUI
import SwiftData

@main
struct DozyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
            Schedule.self,
            Dose.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
