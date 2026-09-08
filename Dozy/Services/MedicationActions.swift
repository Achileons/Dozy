//
//  MedicationActions.swift
//  Dozy
//

import Foundation
import SwiftData

/// The mutations every screen shares, so a dose can be acted on from wherever it is shown.
enum MedicationActions {

    /// Moves a dose into `status` and keeps its reminder in step.
    static func setStatus(_ status: DoseStatus, for dose: Dose, context: ModelContext) {
        dose.status = status
        dose.takenAt = status == .taken ? Date() : nil
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

        try? context.save()

        Task { await NotificationManager.syncScheduledNotifications(context: context) }
    }
}
