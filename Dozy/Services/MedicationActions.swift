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

    /// A single tap toggles between done and not done; a skipped dose counts as not done.
    static func toggle(_ dose: Dose, context: ModelContext) {
        setStatus(dose.status == .taken ? .pending : .taken, for: dose, context: context)
    }

    /// Removes a medication with the schedules and doses cascading from it, after pulling the
    /// reminders those doses had registered.
    static func delete(_ medication: Medication, context: ModelContext) {
        for dose in medication.doses ?? [] {
            NotificationManager.cancelNotification(for: dose)
        }

        context.delete(medication)
        try? context.save()

        Task { await NotificationManager.syncScheduledNotifications(context: context) }
    }
}
