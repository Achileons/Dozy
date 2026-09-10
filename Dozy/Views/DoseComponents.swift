//
//  DoseComponents.swift
//  Dozy
//

import SwiftUI
import SwiftData

/// One dose, with every way of acting on it attached: tapping toggles it and a long press
/// opens the rest. Shared by the today and calendar screens so both behave identically.
///
/// There is no swipe: a tap already does the one thing a swipe would, and a row that slides
/// under the thumb only gets in the way of the list it sits in.
struct DoseRow: View {
    @Environment(\.modelContext) private var modelContext

    let dose: Dose
    let onEditMedication: (Medication) -> Void
    let onArchiveMedication: (Medication) -> Void

    var body: some View {
        card
            .contentShape(RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous))
            .onTapGesture {
                withAnimation(Motion.spring) {
                    MedicationActions.toggle(dose, context: modelContext)
                }
            }
            // A light tap under the thumb whenever the state actually changes, whichever
            // gesture caused it.
            .sensoryFeedback(.impact(weight: .light), trigger: dose.status)
            .contextMenu { menu }
            .listRowInsets(EdgeInsets(
                top: Spacing.sm, leading: Spacing.lg,
                bottom: Spacing.sm, trailing: Spacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    // MARK: - Card

    private var card: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: dose.status.iconName)
                .font(.dozyIcon(size: Layout.statusIcon))
                .foregroundStyle(dose.status.tint)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: dose.status)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(hex: dose.medication?.colorHex ?? ""))
                        .frame(width: Layout.medicationDot, height: Layout.medicationDot)

                    Text(dose.medication?.name ?? "İlaç")
                        .textStyle(.headline)
                        .foregroundStyle(Palette.primaryText)
                }

                if let dosage = dose.medication?.dosage, !dosage.isEmpty {
                    Text(dosage)
                        .textStyle(.body)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: Spacing.sm)

            Text(dose.scheduledAt, format: .dateTime.hour().minute())
                .textStyle(.numeric)
                .foregroundStyle(Palette.primaryText)
        }
        .frame(minHeight: Layout.minTouchTarget)
        // Only the content recedes once a dose is handled; the card surface itself stays
        // opaque so the row does not turn muddy against the background.
        .opacity(dose.status == .pending ? 1 : Opacity.settled)
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
        withAnimation(Motion.spring) {
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
                .textStyle(.callout)
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

/// A large symbol in the signature colour, so an empty screen still has something warm on it.
struct EmptyIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.dozyIcon(size: Layout.emptyIcon, weight: .light))
            .foregroundStyle(Palette.accent)
            .symbolRenderingMode(.hierarchical)
    }
}

/// An icon, a name for what is missing, a line saying what to do about it, and the button
/// that does it.
struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            EmptyPlaceholder(icon: icon, title: title, detail: detail)
            AddMedicationButton(action: action)
        }
        .padding(.vertical, Spacing.xl)
    }
}

/// A screen that is empty for the moment rather than empty for good: there are medications,
/// today simply has nothing to show. No button, because the bar already carries one.
struct EmptyMessage: View {
    let icon: String
    let title: String
    var detail: String?

    var body: some View {
        EmptyPlaceholder(icon: icon, title: title, detail: detail)
            .padding(Spacing.xl)
    }
}

/// The shared body of both: the icon, the serif title, and the sentence under it.
struct EmptyPlaceholder: View {
    let icon: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: Spacing.md) {
            EmptyIcon(systemName: icon)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .textStyle(.title2)
                    .foregroundStyle(Palette.primaryText)
                    .multilineTextAlignment(.center)

                if let detail {
                    Text(detail)
                        .textStyle(.body)
                        .foregroundStyle(Palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
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
