//
//  ContentView.swift
//  Dozy
//
//  Created by Arda Agovic on 7.09.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Bugün", systemImage: "checklist") {
                TodayView()
            }

            Tab("İlaçlarım", systemImage: "pills") {
                MedicationListView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Medication.self, Schedule.self, Dose.self], inMemory: true)
}
