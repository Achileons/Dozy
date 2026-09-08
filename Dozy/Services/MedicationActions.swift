//
//  MedicationActions.swift
//  Dozy
//

import Foundation
import SwiftData

/// The mutations every screen shares, so a dose can be acted on from wherever it is shown.
enum MedicationActions {

    /// Moves a dose into `status`, keeps its reminder in step, and takes the dose out of the
    /// package it came from. Every screen goes through here, so stock is only ever counted in
    /// one place.
    static func setStatus(_ status: DoseStatus, for dose: Dose, context: ModelContext) {
        let previous = dose.status
        dose.status = status
        dose.takenAt = status == .taken ? Date() : nil

        applyStockChange(from: previous, to: status, for: dose, context: context)
        try? context.save()

        if status == .pending {
            // Pending again means the reminder has to come back.
            Task { await NotificationManager.syncScheduledNotifications(context: context) }
        } else {
            NotificationManager.cancelNotification(for: dose)
        }
    }

    /// A single tap toggles between done and not done.
    static func toggle(_ dose: Dose, context: ModelContext) {
        setStatus(dose.status == .taken ? .pending : .taken, for: dose, context: context)
    }

    /// Moves the package count with the dose: taking one draws it down, undoing puts it back.
    /// Only the crossing in or out of `.taken` counts, so setting the same status twice cannot
    /// draw the package down twice.
    private static func applyStockChange(
        from previous: DoseStatus,
        to status: DoseStatus,
        for dose: Dose,
        context: ModelContext
    ) {
        guard previous != status else { return }
        guard let medication = dose.medication, medication.stockEnabled else { return }

        let units = stockUnits(for: medication)
        if status == .taken {
            // A package cannot hold less than nothing, however many doses are ticked off.
            medication.currentStock = max(0, medication.currentStock - units)
        } else if previous == .taken {
            medication.currentStock += units
        }

        Task { await NotificationManager.updateLowStockNotification(for: medication, context: context) }
    }

    /// What one dose costs the package. Stock is counted in whole units, so a half tablet
    /// still takes one out — rounding the other way would let a package never run down.
    private static func stockUnits(for medication: Medication) -> Int {
        max(1, Int(medication.dosageAmount.rounded()))
    }

    /// Takes a medication out of circulation without erasing what it left behind: the record
    /// is flagged rather than deleted, so every dose already on the calendar keeps the name,
    /// colour and dosage it was recorded with.
    ///
    /// Only doses still ahead are dropped. Anything whose time has passed — taken or missed —
    /// is history and stays exactly where it is.
    static func archive(_ medication: Medication, context: ModelContext) {
        medication.isArchived = true
        medication.archivedAt = Date()

        let now = Date()
        for dose in medication.doses ?? []
        where !dose.isDeleted && dose.status == .pending && dose.scheduledAt >= now {
            NotificationManager.cancelNotification(for: dose)
            context.delete(dose)
        }

        NotificationManager.cancelLowStockNotification(for: medication, context: context)
        try? context.save()

        Task { await NotificationManager.syncScheduledNotifications(context: context) }
    }
}
