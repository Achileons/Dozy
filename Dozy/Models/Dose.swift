//
//  Dose.swift
//  Dozy
//

import Foundation
import SwiftData

/// State of a single planned intake.
enum DoseStatus: Int, Codable, CaseIterable {
    case pending = 0
    case taken = 1
}

@Model
final class Dose {
    var scheduledAt: Date = Date()
    var status: DoseStatus = DoseStatus.pending
    /// Set once the dose is marked as taken.
    var takenAt: Date?
    /// Identifier of the pending `UNNotificationRequest` for this dose.
    var notificationID: String = ""

    var medication: Medication?
    var schedule: Schedule?

    init(
        scheduledAt: Date = Date(),
        status: DoseStatus = .pending,
        takenAt: Date? = nil,
        notificationID: String = "",
        medication: Medication? = nil,
        schedule: Schedule? = nil
    ) {
        self.scheduledAt = scheduledAt
        self.status = status
        self.takenAt = takenAt
        self.notificationID = notificationID
        self.medication = medication
        self.schedule = schedule
    }
}
