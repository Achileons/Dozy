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
                EmptyState(icon: "pills.fill", message: "Henüz ilaç yok") {
                    isAddingMedication = true
                }
            } else {
                list
            }
        }
        // The greeting is the title here; the bar only carries the button.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                            .foregroundStyle(Palette.accent)
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

    /// The header scrolls with the doses rather than sitting above them, so a long day
    /// does not lose a third of the screen to a greeting.
    private var list: some View {
        List {
            header
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm, leading: Spacing.lg,
                    bottom: Spacing.lg, trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if doses.isEmpty {
                EmptyMessage(icon: "cup.and.saucer.fill", message: "Bugün için doz yok")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(doses) { dose in
                    DoseRow(
                        dose: dose,
                        onEditMedication: { medicationBeingEdited = $0 },
                        onArchiveMedication: { medicationPendingArchive = $0 }
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(greeting)
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.primaryText)

                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.turkish)))
                    .font(Typography.itemDetail)
                    .foregroundStyle(Palette.secondaryText)

                if !doses.isEmpty {
                    Text(summary)
                        .font(Typography.itemDetail)
                        .foregroundStyle(isComplete ? Palette.taken : Palette.secondaryText)
                        .padding(.top, Spacing.xs)
                        .contentTransition(.numericText())
                }
            }

            Spacer(minLength: Spacing.sm)

            if !doses.isEmpty {
                ProgressRing(taken: takenCount, total: doses.count)
            }
        }
        .animation(Motion.spring, value: takenCount)
    }

    /// Chosen by the hour, so the screen greets rather than labels.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Günaydın"
        case 12..<18: "İyi günler"
        default: "İyi akşamlar"
        }
    }

    private var takenCount: Int {
        doses.count { $0.status == .taken }
    }

    private var isComplete: Bool {
        !doses.isEmpty && takenCount == doses.count
    }

    private var summary: String {
        isComplete ? "Bugünlük hepsi tamam" : "\(takenCount)/\(doses.count) doz alındı"
    }
}

// MARK: - Progress ring

/// How far through the day's doses the user is, as an arc in the signature colour. Once the
/// arc closes, the count inside gives way to a tick.
private struct ProgressRing: View {
    let taken: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(taken) / Double(total) : 0
    }

    private var isComplete: Bool {
        total > 0 && taken == total
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.ringTrack, lineWidth: Layout.progressStroke)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Palette.accent,
                    style: StrokeStyle(lineWidth: Layout.progressStroke, lineCap: .round)
                )
                // Arcs grow from the top, clockwise, the way a clock fills.
                .rotationEffect(.degrees(-90))
                .animation(Motion.spring, value: fraction)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(Typography.ringValue)
                    .foregroundStyle(Palette.accent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(taken)/\(total)")
                    .font(Typography.ringValue)
                    .foregroundStyle(Palette.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: Layout.progressRing, height: Layout.progressRing)
        .animation(Motion.spring, value: isComplete)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isComplete ? "Bugünkü dozların hepsi alındı" : "\(taken) / \(total) doz alındı")
    }
}
