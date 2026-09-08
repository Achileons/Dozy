//
//  DoseComponents.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// One dose, with every way of acting on it attached: tapping toggles it, swiping marks it
/// taken, and a long press opens the rest. Shared by the today and calendar screens so both
/// behave identically.
struct DoseRow: View {
    @Environment(\.modelContext) private var modelContext

    let dose: Dose
    let onEditMedication: (Medication) -> Void
    let onArchiveMedication: (Medication) -> Void

    var body: some View {
        card
            .contentShape(RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous))
            .onTapGesture {
                withAnimation(.snappy) {
                    MedicationActions.toggle(dose, context: modelContext)
                }
            }
            .contextMenu { menu }
            .listRowInsets(EdgeInsets(
                top: Spacing.sm, leading: Spacing.lg,
                bottom: Spacing.sm, trailing: Spacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    setStatus(.taken)
                } label: {
                    Label("Aldım", systemImage: DoseStatus.taken.iconName)
                }
                .tint(Palette.taken)
            }
    }

    // MARK: - Card

    private var card: some View {
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

    // MARK: - Menu

    @ViewBuilder
    private var menu: some View {
        // The action matching the current state is left out; it would do nothing.
        if dose.status == .taken {
            Button("Geri al", systemImage: "arrow.uturn.backward") { setStatus(.pending) }
        } else {
            Button("Aldım", systemImage: DoseStatus.taken.iconName) { setStatus(.taken) }
        }

        Divider()

        if let medication = dose.medication {
            Button("İlacı düzenle", systemImage: "pencil") { onEditMedication(medication) }
            Button("İlacı kaldır", systemImage: "archivebox", role: .destructive) {
                onArchiveMedication(medication)
            }
        }
    }

    private func setStatus(_ status: DoseStatus) {
        withAnimation(.snappy) {
            MedicationActions.setStatus(status, for: dose, context: modelContext)
        }
    }
}

// MARK: - Empty state

/// The one large call to action, shown wherever a screen has nothing to list because no
/// medication has been added yet. It is the only add button on such a screen; the small
/// one in the bar steps aside for it.
struct AddMedicationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("İlaç ekle", systemImage: "plus")
                .font(Typography.control)
                .foregroundStyle(Palette.accentLabel)
                .frame(maxWidth: .infinity, minHeight: Layout.actionButton)
                .background(
                    Palette.accentFill,
                    in: RoundedRectangle(cornerRadius: Layout.controlCorner, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xl)
    }
}

/// One line and one large button — nothing to read, one thing to do.
struct EmptyState: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text(message)
                .font(Typography.itemTitle)
                .foregroundStyle(Palette.secondaryText)

            AddMedicationButton(action: action)
        }
        .padding(.vertical, Spacing.xl)
    }
}

/// A screen that is empty for the moment rather than empty for good: there are medications,
/// today simply has nothing to show. No button, because the bar already carries one.
struct EmptyMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Typography.itemTitle)
            .foregroundStyle(Palette.secondaryText)
            .padding(Spacing.xl)
    }
}

// MARK: - Deletion confirmation

extension View {
    /// The confirmation shared by every screen that can remove a medication. An alert rather
    /// than a sheet, so a choice this large lands in the middle of the screen instead of
    /// under the thumb that just swiped.
    func archiveMedicationConfirmation(
        medication: Binding<Medication?>,
        onConfirm: @escaping (Medication) -> Void
    ) -> some View {
        alert(
            "İlacı kaldır",
            isPresented: Binding(
                get: { medication.wrappedValue != nil },
                set: { if !$0 { medication.wrappedValue = nil } }
            ),
            presenting: medication.wrappedValue
        ) { target in
            Button("Vazgeç", role: .cancel) {}
            Button("Kaldır", role: .destructive) { onConfirm(target) }
        } message: { target in
            Text("\(target.name) kaldırılacak. Geçmiş kayıtların takvimde kalmaya devam edecek.")
        }
    }
}
