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

    @State private var isAddingMedication = false
    @State private var medicationBeingEdited: Medication?
    @State private var medicationPendingDeletion: Medication?

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

            if doses.isEmpty {
                EmptyState(message: "Bugün için doz yok") { isAddingMedication = true }
            } else {
                list
            }
        }
        .navigationTitle(day.formatted(.dateTime.day().month(.wide).locale(.turkish)))
        .navigationSubtitle(summary)
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
        .sheet(isPresented: $isAddingMedication) {
            MedicationFormView()
        }
        .sheet(item: $medicationBeingEdited) { medication in
            MedicationFormView(medication: medication)
        }
        .deleteMedicationConfirmation(medication: $medicationPendingDeletion) { medication in
            MedicationActions.delete(medication, context: modelContext)
        }
    }

    private var list: some View {
        List {
            ForEach(doses) { dose in
                DoseRow(dose: dose)
                    .contentShape(RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous))
                    .onTapGesture {
                        withAnimation(.snappy) {
                            MedicationActions.toggle(dose, context: modelContext)
                        }
                    }
                    .contextMenu { menu(for: dose) }
                    .listRowInsets(EdgeInsets(
                        top: Spacing.sm, leading: Spacing.lg,
                        bottom: Spacing.sm, trailing: Spacing.lg
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            setStatus(.taken, for: dose)
                        } label: {
                            Label("Aldım", systemImage: DoseStatus.taken.iconName)
                        }
                        .tint(Palette.taken)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            setStatus(.skipped, for: dose)
                        } label: {
                            Label("Atla", systemImage: DoseStatus.skipped.iconName)
                        }
                        .tint(Palette.skipped)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func menu(for dose: Dose) -> some View {
        // The action matching the current state is left out; it would do nothing.
        if dose.status != .taken {
            Button("Aldım", systemImage: DoseStatus.taken.iconName) {
                setStatus(.taken, for: dose)
            }
        }
        if dose.status != .skipped {
            Button("Atla", systemImage: DoseStatus.skipped.iconName) {
                setStatus(.skipped, for: dose)
            }
        }
        if dose.status != .pending {
            Button("Geri al", systemImage: "arrow.uturn.backward") {
                setStatus(.pending, for: dose)
            }
        }

        Divider()

        if let medication = dose.medication {
            Button("İlacı düzenle", systemImage: "pencil") {
                medicationBeingEdited = medication
            }
            Button("İlacı sil", systemImage: "trash", role: .destructive) {
                medicationPendingDeletion = medication
            }
        }
    }

    private var summary: String {
        let takenCount = doses.count { $0.status == .taken }
        return "\(takenCount)/\(doses.count) alındı"
    }

    private func setStatus(_ status: DoseStatus, for dose: Dose) {
        withAnimation(.snappy) {
            MedicationActions.setStatus(status, for: dose, context: modelContext)
        }
    }
}

// MARK: - Dose row

private struct DoseRow: View {
    let dose: Dose

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: dose.status.iconName)
                .font(.system(size: Layout.statusIcon))
                .foregroundStyle(dose.status.tint)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: dose.medication?.colorHex ?? ""))
                        .frame(width: Layout.medicationDot, height: Layout.medicationDot)

                    Text(dose.medication?.name ?? "İlaç")
                        .font(Typography.itemTitle)
                        .foregroundStyle(Palette.primaryText)
                }

                if let dosage = dose.medication?.dosage, !dosage.isEmpty {
                    Text(dosage)
                        .font(Typography.itemDetail)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: Spacing.sm)

            Text(dose.scheduledAt, format: .dateTime.hour().minute())
                .font(Typography.time)
                .foregroundStyle(Palette.primaryText)
                .monospacedDigit()
        }
        .frame(minHeight: Layout.minTouchTarget)
        // Only the content recedes once a dose is handled; the card surface itself stays
        // opaque so the row does not turn muddy against the background.
        .opacity(dose.status == .pending ? 1 : 0.55)
        .dozyCard()
        .accessibilityElement(children: .combine)
        .accessibilityValue(dose.status.accessibilityTitle)
    }
}

// MARK: - Empty state

/// One line and one large button — nothing to read, one thing to do.
struct EmptyState: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text(message)
                .font(Typography.itemTitle)
                .foregroundStyle(Palette.secondaryText)

            Button(action: action) {
                Label("İlaç ekle", systemImage: "plus")
                    .font(Typography.control)
                    .foregroundStyle(Palette.accentLabel)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        Palette.accentFill,
                        in: RoundedRectangle(cornerRadius: Layout.controlCorner, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Deletion confirmation

extension View {
    /// The confirmation shared by every screen that can delete a medication.
    func deleteMedicationConfirmation(
        medication: Binding<Medication?>,
        onConfirm: @escaping (Medication) -> Void
    ) -> some View {
        confirmationDialog(
            "İlacı sil",
            isPresented: Binding(
                get: { medication.wrappedValue != nil },
                set: { if !$0 { medication.wrappedValue = nil } }
            ),
            presenting: medication.wrappedValue
        ) { target in
            Button("Sil", role: .destructive) { onConfirm(target) }
            Button("Vazgeç", role: .cancel) {}
        } message: { target in
            Text("\(target.name) silinecek, geçmiş kayıtları da gidecek.")
        }
    }
}
