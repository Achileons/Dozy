//
//  MedicationListView.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// Every medication the user keeps, with its schedule summarised underneath.
struct MedicationListView: View {
    @Environment(\.modelContext) private var modelContext
    /// Archived medications are gone from the user's point of view; only their doses
    /// linger, on the days they were recorded.
    @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.name, order: .forward)
    private var medications: [Medication]

    @State private var isAddingMedication = false
    @State private var medicationBeingEdited: Medication?
    @State private var medicationPendingArchive: Medication?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()

                if medications.isEmpty {
                    EmptyState(
                        icon: "pills.fill",
                        title: "Henüz ilaç yok",
                        detail: "Eklediğin ilaçlar ve programları burada görünecek."
                    ) {
                        isAddingMedication = true
                    }
                } else {
                    list
                }
            }
            .navigationTitle("İlaçlarım")
            .toolbar {
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
        .environment(\.locale, .turkish)
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

    /// What the whole list adds up to: how many medications, and how many times a day they
    /// ask for something. Averaged, so a rule that skips days does not read as a daily one.
    private var summary: String {
        let perDay = medications.reduce(0) { running, medication in
            running + StockCalculator.dailyDoseCount(for: medication)
        }
        let formatted = perDay.formatted(
            .number.precision(.fractionLength(0...1)).locale(.turkish)
        )
        return "\(medications.count) ilaç · \(formatted) doz/gün"
    }

    private var list: some View {
        List {
            Text(summary)
                .textStyle(.callout)
                .foregroundStyle(Palette.secondaryText)
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm, leading: Spacing.lg,
                    bottom: 0, trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(medications) { medication in
                MedicationRow(medication: medication)
                    .contentShape(RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous))
                    .onTapGesture { medicationBeingEdited = medication }
                    .contextMenu {
                        Button("Düzenle", systemImage: "pencil") {
                            medicationBeingEdited = medication
                        }
                        Button("Kaldır", systemImage: "archivebox", role: .destructive) {
                            medicationPendingArchive = medication
                        }
                    }
                    .listRowInsets(EdgeInsets(
                        top: Spacing.sm, leading: Spacing.lg,
                        bottom: Spacing.sm, trailing: Spacing.lg
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            medicationPendingArchive = medication
                        } label: {
                            Label("Kaldır", systemImage: "archivebox")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Row

private struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: medication.colorHex))
                        .frame(width: Layout.medicationDot, height: Layout.medicationDot)

                    Text(medication.name)
                        .textStyle(.headline)
                        .foregroundStyle(Palette.primaryText)
                }
                .padding(.trailing, medication.stockEnabled ? Layout.stockIcon : 0)

                if !medication.dosage.isEmpty {
                    Text(medication.dosage)
                        .textStyle(.body)
                        .foregroundStyle(Palette.secondaryText)
                }

                Text(ScheduleSummary.text(for: medication.schedules?.first))
                    .textStyle(.caption)
                    .foregroundStyle(Palette.secondaryText)

                if let next = nextDoseText {
                    Text(next)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.accent)
                }

                // Only shown while the medication counts its package, and tinted once that
                // package is down to the threshold the user set.
                if let stock = StockCalculator.summary(for: medication) {
                    Text(stock)
                        .textStyle(.caption)
                        .foregroundStyle(medication.stockTextTint)
                }
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.dozyIcon(.caption, weight: .semibold))
                .foregroundStyle(Palette.pending)
        }
        .frame(minHeight: Layout.minTouchTarget)
        // Only a medication counting its package has a level to report. It sits in the
        // corner, clear of the chevron, so the row reads the same with or without it.
        .overlay(alignment: .topTrailing) {
            if medication.stockEnabled {
                StockIndicator(
                    fraction: medication.stockFraction,
                    tint: medication.stockTint
                )
            }
        }
        // The stripe and the pill are the same colour by construction: both ask the
        // medication what its package has to say.
        .dozyCard(stripe: medication.stockTint)
        .accessibilityElement(children: .combine)
    }

    /// When this medication is next due. Named relatively for the two days that have names,
    /// since "yarın 08:00" is read faster than a date is.
    private var nextDoseText: String? {
        guard let next = medication.nextDose() else { return nil }

        let calendar = Calendar.current
        let time = next.scheduledAt.formatted(.dateTime.hour().minute().locale(.turkish))

        if calendar.isDateInToday(next.scheduledAt) {
            return "Sonraki: bugün \(time)"
        }
        if calendar.isDateInTomorrow(next.scheduledAt) {
            return "Sonraki: yarın \(time)"
        }

        let day = next.scheduledAt.formatted(.dateTime.day().month(.wide).locale(.turkish))
        return "Sonraki: \(day) \(time)"
    }
}

// MARK: - Summary

/// Turns a schedule into a line like "Her gün 08:00, 20:00".
enum ScheduleSummary {
    static func text(for schedule: Schedule?) -> String {
        guard let schedule, !schedule.times.isEmpty else { return "Program yok" }

        let times = schedule.times
            .sorted()
            .map { $0.formatted(.dateTime.hour().minute().locale(.turkish)) }
            .joined(separator: ", ")

        return "\(rule(for: schedule)) \(times)"
    }

    private static func rule(for schedule: Schedule) -> String {
        switch schedule.repeatRule {
        case .daily:
            return "Her gün"

        case .specificWeekdays:
            guard !schedule.weekdays.isEmpty else { return "Gün seçilmedi" }
            // Monday first for reading, while the stored values keep Calendar's 1 = Sunday.
            let ordered = [2, 3, 4, 5, 6, 7, 1].filter(schedule.weekdays.contains)
            return ordered.compactMap(symbol(forWeekday:)).joined(separator: ", ")

        case .everyNDays:
            // An interval of one is every day, and saying so plainly beats "1 günde bir".
            let interval = max(1, schedule.intervalDays)
            return interval == 1 ? "Her gün" : "\(interval) günde bir"
        }
    }

    static func symbol(forWeekday weekday: Int) -> String? {
        let symbols = turkishCalendar.shortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return nil }
        return symbols[weekday - 1]
    }

    private static let turkishCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .turkish
        return calendar
    }()
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Medication.self, Schedule.self, Dose.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let calendar = Calendar.current
    let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()

    let samples: [(String, String, String, RepeatRule, [Date], [Int])] = [
        ("Parol", "500 mg, 1 tablet", "#E4572E", .daily, [morning, evening], []),
        ("D Vitamini", "1000 IU", "#F3A712", .specificWeekdays, [morning], [2, 4, 6]),
        ("Omega 3", "2 kapsül", "#2E9E6B", .daily, [evening], [])
    ]

    for (name, dosage, hex, rule, times, weekdays) in samples {
        let medication = Medication(name: name, dosage: dosage, colorHex: hex)
        container.mainContext.insert(medication)
        let schedule = Schedule(times: times, repeatRule: rule, weekdays: weekdays)
        container.mainContext.insert(schedule)
        schedule.medication = medication
    }

    return MedicationListView().modelContainer(container)
}
