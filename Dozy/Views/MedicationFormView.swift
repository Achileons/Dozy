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
    @State private var dosageUnit: DosageUnit
    @State private var dosageAmount: Double
    @State private var notes: String
    @State private var colorHex: String
    @State private var times: [TimeSlot]
    @State private var repeatRule: RepeatRule
    @State private var weekdays: Set<Int>
    @State private var intervalDays: Int
    @State private var stockEnabled: Bool
    @State private var currentStock: Int
    @State private var packageSize: Int
    @State private var lowStockThreshold: Int
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    /// Set while the time picker is up. A time only joins the list once it is confirmed
    /// there, so backing out of the sheet leaves the schedule untouched.
    @State private var timeBeingAdded: TimeSlot?
    @State private var medicationPendingArchive: Medication?

    @State private var isScanning = false
    /// The code the box was last scanned with; kept across edits so a name the user tidies
    /// up by hand stays tied to the product it came from.
    @State private var gtin: String?
    /// Why the last scan filled nothing in. Cleared as soon as the name is typed into.
    @State private var scanNotice: String?

    init(medication: Medication? = nil) {
        self.medication = medication

        // A medication may in theory carry several schedules; this form edits the first one.
        let schedule = medication?.schedules?.first
        let times = schedule?.times.sorted() ?? []

        _name = State(initialValue: medication?.name ?? "")
        _gtin = State(initialValue: medication?.gtin)
        _dosageUnit = State(initialValue: medication?.unit ?? .tablet)
        _dosageAmount = State(initialValue: medication?.dosageAmount ?? 1)
        _notes = State(initialValue: medication?.notes ?? "")
        _colorHex = State(initialValue: medication?.colorHex ?? Self.colorOptions[0])
        _times = State(initialValue: times.map(TimeSlot.init))
        _repeatRule = State(initialValue: schedule?.repeatRule ?? .daily)
        _weekdays = State(initialValue: Set(schedule?.weekdays ?? []))
        _intervalDays = State(initialValue: schedule?.intervalDays ?? Self.defaultInterval)
        _stockEnabled = State(initialValue: medication?.stockEnabled ?? false)
        _currentStock = State(initialValue: medication?.currentStock ?? 0)
        _packageSize = State(initialValue: medication?.packageSize ?? 0)

        // A medication from before stock tracking carries a threshold of zero, which would
        // only warn once the package was already empty.
        let storedThreshold = medication?.lowStockThreshold ?? 0
        _lowStockThreshold = State(
            initialValue: storedThreshold > 0 ? storedThreshold : Self.defaultLowStockThreshold
        )
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
                        dosageCard
                        colorCard
                        timesCard
                        repeatCard
                        periodCard
                        stockCard

                        if medication != nil {
                            archiveButton
                        }
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
        .sheet(isPresented: $isScanning) {
            ScannerView(onScan: handleScan)
        }
        .sheet(item: $timeBeingAdded) { slot in
            TimePickerSheet(initialTime: slot.date) { time in
                withAnimation(.snappy) { times.append(TimeSlot(date: time)) }
            }
        }
        .archiveMedicationConfirmation(medication: $medicationPendingArchive) { medication in
            MedicationActions.archive(medication, context: modelContext)
            dismiss()
        }
    }

    // MARK: - Cards

    private var detailsCard: some View {
        FormCard {
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    FormField(placeholder: "İlaç adı", text: $name)

                    Button {
                        isScanning = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundStyle(Palette.primaryText)
                            .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Karekodu veya barkodu okut")
                }

                if let scanNotice {
                    Text(scanNotice)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.missed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                Divider()
                FormField(placeholder: "Not", text: $notes)
            }
        }
        .onChange(of: name) { _, _ in
            withAnimation(.snappy) { scanNotice = nil }
        }
    }

    /// Dose is picked rather than typed: a unit, then an amount. The two are stored side by
    /// side and only joined into `dosage` when saving.
    private var dosageCard: some View {
        FormCard(title: "Doz") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // The six units do not fit across a phone, so the row scrolls rather than
                // wrapping the buttons onto a ragged second line.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(DosageUnit.allCases) { unit in
                            SelectableChip(title: unit.title, isOn: unit == dosageUnit) {
                                withAnimation(.snappy) { dosageUnit = unit }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                }
                .scrollClipDisabled()
                .padding(.horizontal, -Spacing.xs)

                Divider()

                Stepper(
                    value: $dosageAmount,
                    in: Self.amountRange,
                    step: Self.amountStep
                ) {
                    Text(Medication.dosageText(amount: dosageAmount, unit: dosageUnit))
                        .font(Typography.itemTitle)
                        .foregroundStyle(Palette.primaryText)
                }
                .frame(minHeight: Layout.minTouchTarget)
                .accessibilityLabel("Miktar")
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

                        Button {
                            withAnimation(.snappy) { times.removeAll { $0.id == slot.id } }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundStyle(Palette.missed)
                                .frame(
                                    width: Layout.minTouchTarget,
                                    height: Layout.minTouchTarget,
                                    alignment: .trailing
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Saati sil")
                    }
                    .frame(minHeight: Layout.minTouchTarget)
                }

                if !times.isEmpty {
                    Divider()
                }

                Button {
                    timeBeingAdded = TimeSlot(date: nextSuggestedTime())
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
                    Text("Aralıklı").tag(RepeatRule.everyNDays)
                }
                .pickerStyle(.segmented)

                if repeatRule == .specificWeekdays {
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
                }

                if repeatRule == .everyNDays {
                    Stepper(value: $intervalDays, in: Self.intervalRange) {
                        Text("\(intervalDays) günde bir")
                            .font(Typography.itemDetail)
                            .foregroundStyle(Palette.primaryText)
                    }
                    .frame(minHeight: Layout.minTouchTarget)
                    .accessibilityLabel("Gün aralığı")
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

    /// Removing lives at the bottom of the form rather than in the bar, so it is reached
    /// deliberately and never next to "Kaydet".
    private var archiveButton: some View {
        Button {
            medicationPendingArchive = medication
        } label: {
            Label("Bu ilacı kaldır", systemImage: "archivebox")
                .font(Typography.control)
                .foregroundStyle(Palette.missed)
                .frame(maxWidth: .infinity, minHeight: Layout.actionButton)
                .background(
                    Palette.card,
                    in: RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
                        .strokeBorder(Palette.missed.opacity(0.4), lineWidth: Layout.border)
                }
        }
        .buttonStyle(.plain)
    }

    private var stockCard: some View {
        FormCard(title: "Stok") {
            VStack(spacing: Spacing.xs) {
                Toggle("Stok takibi", isOn: $stockEnabled.animation(.snappy))
                    .font(Typography.itemDetail)
                    .frame(minHeight: Layout.minTouchTarget)

                if stockEnabled {
                    Divider()

                    CountStepper(
                        title: "Eldeki miktar",
                        value: $currentStock,
                        range: Self.stockRange
                    )

                    Divider()

                    CountStepper(
                        title: "Kutu büyüklüğü",
                        value: $packageSize,
                        range: Self.stockRange
                    )

                    Divider()

                    CountStepper(
                        title: "Uyarı eşiği",
                        value: $lowStockThreshold,
                        range: Self.thresholdRange
                    )
                }
            }
        }
    }

    // MARK: - Scanning

    /// Turns a scanned code into form values. Nothing the user typed is touched unless the
    /// product is actually found, and even then every field stays editable.
    private func handleScan(_ result: ScanResult?) {
        guard let result else {
            withAnimation(.snappy) { scanNotice = "Kod okunamadı, adı elle girebilirsin" }
            return
        }

        guard let productName = MedicationDatabase.shared.lookup(barcode: result.barcode) else {
            withAnimation(.snappy) {
                scanNotice = "Bu ilaç veritabanında bulunamadı, adı elle girebilirsin"
            }
            return
        }

        withAnimation(.snappy) {
            scanNotice = nil
            name = productName
            gtin = result.barcode

            // The registered name usually ends in what the box holds, which is exactly
            // the package size. Offered, not imposed: the card opens so it can be seen.
            if let contents = Self.packageContents(in: productName) {
                stockEnabled = true
                packageSize = contents.count
                if currentStock == 0 {
                    currentStock = contents.count
                }
                if let unit = contents.unit {
                    dosageUnit = unit
                }
            }
        }
    }

    /// The count and unit a product name ends with — "20 TABLET", "100 ML" — or `nil` when
    /// it names none. The last match wins, since the strength comes first and the pack
    /// contents last; a number right after a slash is a strength ("100 MG/5 ML") and is
    /// skipped.
    static func packageContents(in productName: String) -> (count: Int, unit: DosageUnit?)? {
        let name = productName.uppercased(with: .turkish)
        let pattern = /(\d+)\s*(TABLET|KAPSÜL|KAPSUL|DRAJE|ŞASE|SAŞE|SASE|AMPUL|FLAKON|ADET|PASTİL|SUPOZİTUVAR|DAMLA|ML)\b/

        for match in name.matches(of: pattern).reversed() {
            // Only look behind the match when there is something there to look at.
            if match.range.lowerBound > name.startIndex,
               name[name.index(before: match.range.lowerBound)] == "/" {
                continue
            }
            guard let count = Int(match.output.1), count > 0 else { continue }

            let unit: DosageUnit? = switch match.output.2 {
            case "TABLET": .tablet
            case "KAPSÜL", "KAPSUL": .capsule
            case "ŞASE", "SAŞE", "SASE": .sachet
            case "AMPUL", "FLAKON": .injection
            case "DAMLA": .drop
            case "ML": .syrup
            default: nil
            }
            return (count, unit)
        }

        return nil
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
        medication.dosage = Medication.dosageText(amount: dosageAmount, unit: dosageUnit)
        medication.dosageUnit = dosageUnit.rawValue
        medication.dosageAmount = dosageAmount
        medication.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.colorHex = colorHex
        medication.gtin = gtin
        // The counts are kept even while tracking is off, so switching it back on does not
        // start from an empty package. Everything downstream gates on `stockEnabled`.
        medication.stockEnabled = stockEnabled
        medication.currentStock = currentStock
        medication.packageSize = packageSize
        medication.lowStockThreshold = lowStockThreshold

        let schedule = medication.schedules?.first ?? {
            let schedule = Schedule()
            modelContext.insert(schedule)
            schedule.medication = medication
            return schedule
        }()

        schedule.times = normalizedTimes()
        schedule.repeatRule = repeatRule
        schedule.weekdays = repeatRule == .specificWeekdays ? weekdays.sorted() : []
        schedule.intervalDays = repeatRule == .everyNDays ? intervalDays : 1
        schedule.startDate = startDate
        schedule.endDate = hasEndDate ? endDate : nil

        DoseGenerator.regenerateFutureDoses(for: schedule, context: modelContext)
        try? modelContext.save()

        // Reminders are derived from the doses, so they are refreshed once those are stored.
        let context = modelContext
        Task {
            await NotificationManager.syncScheduledNotifications(context: context)
            // The threshold or the amount left may have just moved past each other.
            await NotificationManager.updateLowStockNotification(for: medication, context: context)
        }

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

    /// Half units are the smallest split a tablet is scored for.
    private static let amountRange = 0.5...100.0
    private static let amountStep = 0.5

    private static let stockRange = 0...999
    private static let thresholdRange = 0...99
    private static let defaultLowStockThreshold = 5

    /// Wide enough for "every other day" through to a monthly dose.
    private static let intervalRange = 2...30
    private static let defaultInterval = 2

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

/// Picks one time of day and hands it back only if the user confirms, so "Saat ekle" never
/// puts a row in the list on its own.
private struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var time: Date
    private let onConfirm: (Date) -> Void

    init(initialTime: Date, onConfirm: @escaping (Date) -> Void) {
        _time = State(initialValue: initialTime)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()

                DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(Spacing.lg)
            }
            .navigationTitle("Saat ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        onConfirm(time)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .environment(\.locale, .turkish)
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

/// A labelled whole-number stepper, sized like the other rows in a form card.
private struct CountStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .font(Typography.itemDetail)
                    .foregroundStyle(Palette.secondaryText)

                Spacer(minLength: Spacing.sm)

                Text("\(value)")
                    .font(Typography.itemTitle)
                    .foregroundStyle(Palette.primaryText)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: Layout.minTouchTarget)
        .accessibilityLabel(title)
    }
}

/// One option in a single-choice row. Same treatment as `WeekdayToggle`, but it hugs its
/// label instead of sharing the width evenly.
private struct SelectableChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.control)
                .foregroundStyle(isOn ? Palette.accentLabel : Palette.secondaryText)
                .padding(.horizontal, Spacing.lg)
                .frame(minHeight: Layout.minTouchTarget)
                .background(
                    isOn ? Palette.accentFill : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Layout.controlCorner, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
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
