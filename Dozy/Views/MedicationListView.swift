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
                    EmptyState(message: "Henüz ilaç yok") { isAddingMedication = true }
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
                            .font(Typography.control)
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

    private var list: some View {
        List {
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
                        .font(Typography.itemTitle)
                        .foregroundStyle(Palette.primaryText)
                }

                if !medication.dosage.isEmpty {
                    Text(medication.dosage)
                        .font(Typography.itemDetail)
                        .foregroundStyle(Palette.secondaryText)
                }

                Text(ScheduleSummary.text(for: medication.schedules?.first))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.secondaryText)

                // Only shown while the medication counts its package, and tinted once that
                // package is down to the threshold the user set.
                if let stock = StockCalculator.summary(for: medication) {
                    Text(stock)
                        .font(Typography.meta)
                        .foregroundStyle(
                            medication.isLowOnStock ? Palette.missed : Palette.secondaryText
                        )
                }
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(Typography.meta.weight(.semibold))
                .foregroundStyle(Palette.pending)
        }
        .frame(minHeight: Layout.minTouchTarget)
        .dozyCard()
        .accessibilityElement(children: .combine)
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
