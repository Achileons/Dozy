//
//  CalendarView.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// A month at a glance, with the selected day's doses underneath.
struct CalendarView: View {
    @State private var visibleMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()

                MonthContent(
                    month: visibleMonth,
                    selectedDay: $selectedDay,
                    onMoveMonth: move(by:)
                )
                .id(visibleMonth)
                .transition(Motion.monthTransition)
            }
            .navigationTitle(visibleMonth.formatted(.dateTime.month(.wide).year().locale(.turkish)))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    monthButton(step: -1, systemImage: "chevron.left", label: "Önceki ay")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    monthButton(step: 1, systemImage: "chevron.right", label: "Sonraki ay")
                }
            }
        }
        .environment(\.locale, .turkish)
    }

    private func monthButton(step: Int, systemImage: String, label: String) -> some View {
        Button {
            move(by: step)
        } label: {
            Image(systemName: systemImage)
                .font(Typography.control)
                .foregroundStyle(Palette.accent)
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
        }
        .accessibilityLabel(label)
    }

    /// Moves the calendar a month at a time and keeps the selection inside the month on
    /// screen, so the list below always belongs to what is visible.
    private func move(by months: Int) {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: months, to: visibleMonth) else {
            return
        }

        withAnimation(Motion.gentle) {
            visibleMonth = month

            let today = calendar.startOfDay(for: Date())
            selectedDay = calendar.isDate(today, equalTo: month, toGranularity: .month)
                ? today
                : month
        }
    }
}

// MARK: - Month

/// Everything that depends on the visible month, so a single query covers both the grid and
/// the day list. Recreated whenever the month changes.
private struct MonthContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var doses: [Dose]
    /// Which of the two add paths is offered turns on whether anything has been added at
    /// all, not on what the selected day happens to hold.
    @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.name, order: .forward)
    private var medications: [Medication]
    @Binding var selectedDay: Date

    private let onMoveMonth: (Int) -> Void

    @State private var isAddingMedication = false
    @State private var medicationBeingEdited: Medication?
    @State private var medicationPendingArchive: Medication?

    private let month: Date

    init(month: Date, selectedDay: Binding<Date>, onMoveMonth: @escaping (Int) -> Void) {
        self.month = month
        self._selectedDay = selectedDay
        self.onMoveMonth = onMoveMonth

        let start = month
        let end = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
        _doses = Query(
            filter: #Predicate<Dose> { $0.scheduledAt >= start && $0.scheduledAt < end },
            sort: \Dose.scheduledAt,
            order: .forward
        )
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            grid
            selectedDayHeader
            selectedDayContent
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

    // MARK: Grid

    private var grid: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    Text(ScheduleSummary.symbol(forWeekday: weekday) ?? "")
                        .font(Typography.weekday)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7),
                spacing: Spacing.xs
            ) {
                ForEach(cells) { cell in
                    if let date = cell.date {
                        DayCell(
                            date: date,
                            status: DayStatus(doses: dosesByDay[date] ?? [], now: now),
                            isToday: Calendar.current.isDateInToday(date),
                            isSelected: date == selectedDay
                        )
                        .onTapGesture {
                            withAnimation(Motion.spring) { selectedDay = date }
                        }
                    } else {
                        Color.clear.frame(height: Layout.dayCell)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .contentShape(Rectangle())
        .gesture(monthSwipe)
    }

    /// Swiping the grid moves between months, matching the arrows in the bar.
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: Self.swipeThreshold)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onMoveMonth(value.translation.width < 0 ? 1 : -1)
            }
    }

    // MARK: Selected day

    /// One line saying where the day stands, next to the only thing there is to do here.
    private var selectedDayHeader: some View {
        HStack(spacing: Spacing.sm) {
            Text(statusMessage)
                .font(Typography.itemDetail)
                .foregroundStyle(Palette.secondaryText)

            Spacer(minLength: Spacing.sm)

            // Hidden while the large button below is on screen, so there is only ever one
            // way to add a medication from here.
            if !medications.isEmpty {
                Button {
                    isAddingMedication = true
                } label: {
                    Image(systemName: "plus")
                        .font(Typography.control)
                        .foregroundStyle(Palette.accent)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("İlaç ekle")
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        if medications.isEmpty {
            // Nothing has been added yet, so no day of the month has anything to list: the
            // one thing left to do takes the space under the grid.
            Spacer()
            AddMedicationButton { isAddingMedication = true }
            Spacer()
        } else if selectedDayDoses.isEmpty {
            // The header above already says there is nothing here; repeating it would only
            // fill the space with the same sentence twice.
            Spacer()
        } else {
            List {
                ForEach(selectedDayDoses) { dose in
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
    }

    /// A day that is already over is spoken about in the past tense, so an untouched dose
    /// reads as missed rather than as still waiting for its turn.
    private var statusMessage: String {
        guard !selectedDayDoses.isEmpty else { return "Bu günde doz yok" }

        let remaining = selectedDayDoses.count { $0.status != .taken }
        guard remaining > 0 else { return "Tüm ilaçlar alındı" }

        let isPast = selectedDay < Calendar.current.startOfDay(for: now)
        return isPast ? "\(remaining) ilaç alınmadı" : "\(remaining) ilaç bekliyor"
    }

    // MARK: Derived data

    private var selectedDayDoses: [Dose] {
        dosesByDay[selectedDay] ?? []
    }

    private var dosesByDay: [Date: [Dose]] {
        Dictionary(grouping: doses) { Calendar.current.startOfDay(for: $0.scheduledAt) }
    }

    private var cells: [DayCellSlot] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }

        // Calendar counts weekdays from Sunday; the grid starts on Monday.
        let leadingBlanks = (calendar.component(.weekday, from: month) + 5) % 7

        var slots = (0..<leadingBlanks).map { DayCellSlot(id: -($0 + 1), date: nil) }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: month)
            slots.append(DayCellSlot(id: day, date: date))
        }
        return slots
    }

    /// The moment the grid is judged against. Cheap enough to read once per cell, and the
    /// microseconds between two reads cannot change a day's verdict.
    private var now: Date { Date() }

    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    private static let swipeThreshold: CGFloat = 40
}

// MARK: - Day status

/// What a day has to say for itself. Doses whose time has not come yet are left out of the
/// count, so a day still ahead never looks like a day that was missed.
private enum DayStatus {
    /// Nothing planned, or nothing due yet: the day stays plain either way.
    case quiet
    case allTaken
    case partiallyTaken
    case noneTaken

    init(doses: [Dose], now: Date) {
        // A dose ticked off ahead of time counts as settled even before its hour.
        let settled = doses.filter { $0.scheduledAt <= now || $0.status == .taken }
        guard !settled.isEmpty else {
            self = .quiet
            return
        }

        let taken = settled.count { $0.status == .taken }
        if taken == settled.count {
            self = .allTaken
        } else if taken > 0 {
            self = .partiallyTaken
        } else {
            self = .noneTaken
        }
    }

    /// The wash behind the day number. Muted enough that the number stays the loudest thing
    /// in the cell.
    var fill: Color {
        switch self {
        case .quiet: .clear
        case .allTaken: Palette.takenFill
        case .partiallyTaken: Palette.partialFill
        case .noneTaken: Palette.missedFill
        }
    }

    /// Spoken by VoiceOver, which cannot see the fill.
    var accessibilityTitle: String? {
        switch self {
        case .quiet: nil
        case .allTaken: "Tümü alındı"
        case .partiallyTaken: "Kısmen alındı"
        case .noneTaken: "Alınmadı"
        }
    }
}

// MARK: - Day cell

private struct DayCellSlot: Identifiable {
    let id: Int
    let date: Date?
}

private struct DayCell: View {
    let date: Date
    let status: DayStatus
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            // The wash for how the day went, and over it the ring for whether it is the
            // one being looked at — so picking a day never hides what it was reporting.
            Circle()
                .fill(status.fill)

            Circle()
                .strokeBorder(
                    isSelected ? Palette.accent : .clear,
                    lineWidth: Layout.selectedBorder
                )

            Text(date, format: .dateTime.day())
                .font(Typography.dayNumber)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(Palette.primaryText)
                .monospacedDigit()
        }
        .frame(width: Layout.dayCell, height: Layout.dayCell)
        // Today is marked by weight and a dot rather than by a fill, so the fill is left
        // free to say how the day is going.
        .overlay(alignment: .bottom) {
            if isToday {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: Layout.todayDot, height: Layout.todayDot)
                    .padding(.bottom, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(status.accessibilityTitle ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Helpers

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
