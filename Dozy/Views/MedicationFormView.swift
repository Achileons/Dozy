//
//  MedicationFormView.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// Creates a new medication or edits an existing one, together with its schedule.
struct MedicationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The medication being edited, or `nil` when a new one is created.
    private let medication: Medication?

    @State private var name: String
    @State private var dosage: String
    @State private var notes: String
    @State private var colorHex: String
    @State private var times: [TimeSlot]
    @State private var repeatRule: RepeatRule
    @State private var weekdays: Set<Int>
    @State private var intervalDays: Int
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    init(medication: Medication? = nil) {
        self.medication = medication

        // A medication may in theory carry several schedules; this form edits the first one.
        let schedule = medication?.schedules?.first
        let times = schedule?.times.sorted() ?? []

        _name = State(initialValue: medication?.name ?? "")
        _dosage = State(initialValue: medication?.dosage ?? "")
        _notes = State(initialValue: medication?.notes ?? "")
        _colorHex = State(initialValue: medication?.colorHex ?? Self.colorOptions[0])
        _times = State(initialValue: (times.isEmpty ? [Self.defaultTime] : times).map(TimeSlot.init))
        _repeatRule = State(initialValue: schedule?.repeatRule ?? .daily)
        _weekdays = State(initialValue: Set(schedule?.weekdays ?? []))
        _intervalDays = State(initialValue: max(1, schedule?.intervalDays ?? 1))
        _startDate = State(initialValue: schedule?.startDate ?? Date())
        _hasEndDate = State(initialValue: schedule?.endDate != nil)
        _endDate = State(initialValue: schedule?.endDate ?? Self.defaultEndDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        detailsCard
                        colorCard
                        timesCard
                        repeatCard
                        periodCard
                    }
                    .padding(Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(medication == nil ? "Yeni İlaç" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .environment(\.locale, .turkish)
    }

    // MARK: - Cards

    private var detailsCard: some View {
        FormCard {
            VStack(spacing: Spacing.xs) {
                FormField(placeholder: "İlaç adı", text: $name)
                Divider()
                FormField(placeholder: "Doz", text: $dosage)
                Divider()
                FormField(placeholder: "Not", text: $notes)
            }
        }
    }

    private var colorCard: some View {
        FormCard(title: "Renk") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 4),
                spacing: Spacing.md
            ) {
                ForEach(Self.colorOptions, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: Layout.colorSwatch, height: Layout.colorSwatch)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(Typography.control)
                                    .foregroundStyle(.white)
                                    .opacity(hex == colorHex ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Renk")
                    .accessibilityAddTraits(hex == colorHex ? [.isSelected] : [])
                }
            }
        }
    }

    private var timesCard: some View {
        FormCard(title: "Saatler") {
            VStack(spacing: Spacing.xs) {
                ForEach($times) { $slot in
                    HStack {
                        DatePicker("Saat", selection: $slot.date, displayedComponents: .hourAndMinute)
                            .labelsHidden()

                        Spacer()

                        if times.count > 1 {
                            Button {
                                withAnimation(.snappy) { times.removeAll { $0.id == slot.id } }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.title3)
                                    .foregroundStyle(Palette.skipped)
                                    .frame(
                                        width: Layout.minTouchTarget,
                                        height: Layout.minTouchTarget,
                                        alignment: .trailing
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Saati sil")
                        }
                    }
                    .frame(minHeight: Layout.minTouchTarget)
                }

                Divider()

                Button {
                    withAnimation(.snappy) { times.append(TimeSlot(date: nextSuggestedTime())) }
                } label: {
                    Label("Saat ekle", systemImage: "plus")
                        .font(Typography.control)
                        .foregroundStyle(Palette.primaryText)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var repeatCard: some View {
        FormCard(title: "Tekrar") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("Tekrar kuralı", selection: $repeatRule.animation(.snappy)) {
                    Text("Her gün").tag(RepeatRule.daily)
                    Text("Günler").tag(RepeatRule.specificWeekdays)
                    Text("Aralık").tag(RepeatRule.everyNDays)
                }
                .pickerStyle(.segmented)

                switch repeatRule {
                case .daily:
                    EmptyView()

                case .specificWeekdays:
                    HStack(spacing: Spacing.sm) {
                        ForEach(Self.weekdayOrder, id: \.self) { weekday in
                            WeekdayToggle(
                                title: ScheduleSummary.symbol(forWeekday: weekday) ?? "",
                                isOn: weekdays.contains(weekday)
                            ) {
                                withAnimation(.snappy) {
                                    if weekdays.contains(weekday) {
                                        weekdays.remove(weekday)
                                    } else {
                                        weekdays.insert(weekday)
                                    }
                                }
                            }
                        }
                    }

                case .everyNDays:
                    Stepper(value: $intervalDays, in: 1...30) {
                        Text("\(intervalDays) günde bir")
                            .font(Typography.itemDetail)
                            .foregroundStyle(Palette.primaryText)
                    }
                    .frame(minHeight: Layout.minTouchTarget)
                }
            }
        }
    }

    private var periodCard: some View {
        FormCard(title: "Süre") {
            VStack(spacing: Spacing.xs) {
                DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                    .font(Typography.itemDetail)
                    .frame(minHeight: Layout.minTouchTarget)

                Divider()

                Toggle("Bitiş", isOn: $hasEndDate.animation(.snappy))
                    .font(Typography.itemDetail)
                    .frame(minHeight: Layout.minTouchTarget)

                if hasEndDate {
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Saving

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty, !times.isEmpty else { return false }
        if repeatRule == .specificWeekdays && weekdays.isEmpty { return false }
        return true
    }

    private func save() {
        guard canSave else { return }

        let medication = self.medication ?? Medication()
        if self.medication == nil {
            modelContext.insert(medication)
        }

        medication.name = trimmedName
        medication.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.colorHex = colorHex

        let schedule = medication.schedules?.first ?? {
            let schedule = Schedule()
            modelContext.insert(schedule)
            schedule.medication = medication
            return schedule
        }()

        schedule.times = normalizedTimes()
        schedule.repeatRule = repeatRule
        schedule.weekdays = repeatRule == .specificWeekdays ? weekdays.sorted() : []
        schedule.intervalDays = repeatRule == .everyNDays ? max(1, intervalDays) : 1
        schedule.startDate = startDate
        schedule.endDate = hasEndDate ? endDate : nil

        DoseGenerator.regenerateFutureDoses(for: schedule, context: modelContext)
        try? modelContext.save()

        // Reminders are derived from the doses, so they are refreshed once those are stored.
        let context = modelContext
        Task { await NotificationManager.syncScheduledNotifications(context: context) }

        dismiss()
    }

    /// Drops duplicate hour/minute pairs and returns the times in order.
    private func normalizedTimes() -> [Date] {
        let calendar = Calendar.current
        var seen = Set<Int>()

        return times.map(\.date)
            .sorted { minuteOfDay($0, calendar: calendar) < minuteOfDay($1, calendar: calendar) }
            .filter { seen.insert(minuteOfDay($0, calendar: calendar)).inserted }
    }

    private func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// An hour after the latest time already in the list, so added rows do not collide.
    private func nextSuggestedTime() -> Date {
        guard let latest = times.map(\.date).max() else { return Self.defaultTime }
        return Calendar.current.date(byAdding: .hour, value: 1, to: latest) ?? latest
    }

    // MARK: - Constants

    static let colorOptions = [
        "#4A90E2", "#2E9E6B", "#F3A712", "#E4572E",
        "#E45FA0", "#7B61FF", "#00A6A6", "#6B7A8F"
    ]

    /// Monday first for display, mapped onto `Calendar`'s 1 = Sunday numbering.
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static var defaultEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    }
}

// MARK: - Building blocks

/// A time of day the user added. Wrapped in an identity so rows survive reordering and
/// deletion without SwiftUI ever reading a stale index.
private struct TimeSlot: Identifiable {
    let id = UUID()
    var date: Date

    init(date: Date) {
        self.date = date
    }
}

/// A card with an optional short title. The fields inside carry their own placeholders.
private struct FormCard<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let title {
                Text(title)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.secondaryText)
            }

            content
        }
        .dozyCard()
    }
}

private struct FormField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Typography.itemTitle)
            .foregroundStyle(Palette.primaryText)
            .textInputAutocapitalization(.sentences)
            .frame(minHeight: Layout.minTouchTarget)
    }
}

private struct WeekdayToggle: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.control)
                .foregroundStyle(isOn ? Palette.accentLabel : Palette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                .background(
                    isOn ? Palette.accentFill : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Layout.controlCorner, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("Yeni ilaç") {
    MedicationFormView()
        .modelContainer(for: [Medication.self, Schedule.self, Dose.self], inMemory: true)
}
