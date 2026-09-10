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
                EmptyState(
                    icon: "pills.fill",
                    title: "Henüz ilaç yok",
                    detail: "İlk ilacını ekle, dozlarını buradan takip edelim."
                ) {
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
                            .font(.dozyIcon(.callout, weight: .semibold))
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
                EmptyMessage(
                    icon: "cup.and.saucer.fill",
                    title: "Bugün için doz yok",
                    detail: "Bugüne planlanmış bir doz bulunmuyor."
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                listTitle

                ForEach(groups) { group in
                    Section {
                        ForEach(group.doses) { dose in
                            DoseRow(
                                dose: dose,
                                onEditMedication: { medicationBeingEdited = $0 },
                                onArchiveMedication: { medicationPendingArchive = $0 }
                            )
                        }
                    } header: {
                        partHeader(group.part)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var listTitle: some View {
        Text("Bugünün dozları")
            .textStyle(.callout)
            .foregroundStyle(Palette.primaryText)
            .listRowInsets(EdgeInsets(
                top: Spacing.xs, leading: Spacing.lg,
                bottom: 0, trailing: Spacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Quieter than the title above it, so the two read as a heading and its subdivisions
    /// rather than as two competing labels.
    private func partHeader(_ part: DayPart) -> some View {
        Text(part.title)
            .textStyle(.caption)
            .foregroundStyle(Palette.secondaryText)
            .textCase(nil)
            .listRowInsets(EdgeInsets(
                top: Spacing.md, leading: Spacing.lg,
                bottom: Spacing.xs, trailing: Spacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(greeting)
                    .textStyle(.largeTitle)
                    .foregroundStyle(Palette.primaryText)
                    .minimumScaleFactor(Layout.titleScale)
                    .lineLimit(1)

                Text(day.formatted(.dateTime.day().month(.wide).weekday(.wide).locale(.turkish)))
                    .textStyle(.caption)
                    .foregroundStyle(Palette.secondaryText)
            }

            Spacer(minLength: Spacing.sm)

            if !doses.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ProgressRing(taken: takenCount, total: doses.count)

                    Text(ringSummary)
                        .textStyle(.caption)
                        .foregroundStyle(isComplete ? Palette.taken : Palette.secondaryText)
                        .contentTransition(.numericText())
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.spring, value: takenCount)
    }

    /// Chosen by the hour, so the screen greets rather than labels.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: "Günaydın"
        case 11..<17: "İyi günler"
        case 17..<22: "İyi akşamlar"
        default: "İyi geceler"
        }
    }

    /// What is left rather than what is done: the number that decides whether the user can
    /// put the phone down.
    private var ringSummary: String {
        isComplete ? "Bugün tamam" : "\(doses.count - takenCount) doz kaldı"
    }

    // MARK: - Grouping

    private var groups: [DoseGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: doses) { dose in
            DayPart(hour: calendar.component(.hour, from: dose.scheduledAt))
        }

        // Walked in the order of the day rather than the dictionary's, and parts with
        // nothing in them never appear.
        return DayPart.allCases.compactMap { part in
            guard let doses = grouped[part], !doses.isEmpty else { return nil }
            return DoseGroup(part: part, doses: doses)
        }
    }

    private var takenCount: Int {
        doses.count { $0.status == .taken }
    }

    private var isComplete: Bool {
        !doses.isEmpty && takenCount == doses.count
    }

}

// MARK: - Parts of the day

/// The four stretches a day's doses are grouped under. The bands are deliberately not the
/// greeting's: a dose at half past ten belongs to the morning's doses, while someone opening
/// the app at that hour is well past being greeted with "Günaydın".
private enum DayPart: Int, CaseIterable, Identifiable {
    case morning
    case noon
    case evening
    case night

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .morning: "Sabah"
        case .noon: "Öğlen"
        case .evening: "Akşam"
        case .night: "Gece"
        }
    }

    /// 06–11 morning, 11–17 noon, 17–22 evening, and the rest of the clock night.
    init(hour: Int) {
        switch hour {
        case 6..<11: self = .morning
        case 11..<17: self = .noon
        case 17..<22: self = .evening
        default: self = .night
        }
    }
}

private struct DoseGroup: Identifiable {
    let part: DayPart
    let doses: [Dose]

    var id: Int { part.rawValue }
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
                    .font(.dozyIcon(.numericLarge, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(taken)/\(total)")
                    .textStyle(.numericLarge)
                    .foregroundStyle(Palette.primaryText)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: Layout.progressRing, height: Layout.progressRing)
        .animation(Motion.spring, value: isComplete)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isComplete ? "Bugünkü dozların hepsi alındı" : "\(taken) / \(total) doz alındı")
    }
}
