//
//  ContentView.swift
//  Dozy
//
//  Created by Arda Agovic on 7.09.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    /// The calendar sits in the middle of the bar but is what the app opens on, so the
    /// selection is held rather than left to the first tab.
    @State private var selection: TabIdentifier = .calendar

    var body: some View {
        TabView(selection: $selection) {
            Tab("Bugün", systemImage: "sun.max.fill", value: TabIdentifier.today) {
                TodayView()
            }

            Tab("Takvim", systemImage: "calendar", value: TabIdentifier.calendar) {
                CalendarView()
            }

            Tab("İlaçlarım", systemImage: "pills.fill", value: TabIdentifier.medications) {
                MedicationListView()
            }
        }
        // The selected tab, toggles, pickers and links all take the signature colour.
        .tint(Palette.accent)
    }
}

private enum TabIdentifier {
    case today
    case calendar
    case medications
}

#Preview {
    ContentView()
        .modelContainer(for: [Medication.self, Schedule.self, Dose.self], inMemory: true)
}
