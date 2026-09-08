//
//  TodayView.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// The app's home screen: every dose planned for the current day.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase

    /// The day currently on screen. Kept in state so the list rolls over when the app comes
    /// back to the foreground after midnight.
    @State private var day = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            DayDoseList(day: day)
                .id(day)
        }
        .environment(\.locale, .turkish)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let today = Calendar.current.startOfDay(for: Date())
            if today != day { day = today }
        }
    }
}

// MARK: - Day list

private struct DayDoseList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var doses: [Dose]
    /// Which of the two add paths is offered turns on whether anything has been added at
    /// all, not on whether today happens to be empty.
    @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.name, order: .forward)
    private var medications: [Medication]

    @State private var isAddingMedication = false
    @State private var medicationBeingEdited: Medication?
    @State private var medicationPendingArchive: Medication?

    private let day: Date

    init(day: Date) {
        self.day = day

        let start = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        _doses = Query(
            filter: #Predicate<Dose> { $0.scheduledAt >= start && $0.scheduledAt < end },
            sort: \Dose.scheduledAt,
            order: .forward
        )
    }

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()

            if medications.isEmpty {
                EmptyState(message: "Henüz ilaç yok") { isAddingMedication = true }
            } else if doses.isEmpty {
                EmptyMessage(message: "Bugün için doz yok")
            } else {
                list
            }
        }
        .navigationTitle(day.formatted(.dateTime.day().month(.wide).locale(.turkish)))
        .navigationSubtitle(summary)
        .toolbar {
            // Hidden while the large button below is on screen, so there is only ever one
            // way to add a medication from here.
            if !medications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingMedication = true
                    } label: {
                        Image(systemName: "plus")
                            .font(Typography.control)
                            .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                    }
                    .accessibilityLabel("İlaç ekle")
                }
            }
        }
        .sheet(isPresented: $isAddingMedication) {
            MedicationFormView()
        }
        .sheet(item: $medicationBeingEdited) { medication in
            MedicationFormView(medication: medication)
        }
        .archiveMedicationConfirmation(medication: $medicationPendingArchive) { medication in
            MedicationActions.archive(medication, context: modelContext)
        }
    }

    private var list: some View {
        List {
            ForEach(doses) { dose in
                DoseRow(
                    dose: dose,
                    onEditMedication: { medicationBeingEdited = $0 },
                    onArchiveMedication: { medicationPendingArchive = $0 }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var summary: String {
        let takenCount = doses.count { $0.status == .taken }
        return "\(takenCount)/\(doses.count) alındı"
    }
}
