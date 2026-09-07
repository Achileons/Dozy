//
//  NotificationManager.swift
//  Dozy
//

import Foundation
import SwiftData
import UserNotifications

/// Keeps the local notifications in sync with the pending doses stored in SwiftData.
enum NotificationManager {

    /// iOS keeps at most 64 pending requests per app; staying below that leaves room for
    /// anything scheduled outside of this sync.
    static let maxScheduledNotifications = 50

    // MARK: - Authorization

    /// Asks for permission to post reminders. Returns whether the app may schedule them.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Sync

    /// Rebuilds the whole set of pending notifications from the store: the next
    /// `maxScheduledNotifications` upcoming doses get a request, everything else is dropped.
    ///
    /// Safe to call repeatedly — it is meant to run on every launch and after any change to
    /// the schedules, since it always derives the requests from the current data.
    static func syncScheduledNotifications(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        guard await isAuthorized(center: center) else {
            center.removeAllPendingNotificationRequests()
            return
        }

        let doses = upcomingPendingDoses(context: context)

        // Drop everything first so doses that were taken, skipped or rescheduled in the
        // meantime cannot leave a stale reminder behind.
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        var didAssignIdentifier = false

        for dose in doses {
            // Doses created outside of DoseGenerator may still be missing an identifier.
            if dose.notificationID.isEmpty {
                dose.notificationID = UUID().uuidString
                didAssignIdentifier = true
            }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dose.scheduledAt
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: dose.notificationID,
                content: content(for: dose),
                trigger: trigger
            )

            try? await center.add(request)
        }

        if didAssignIdentifier {
            try? context.save()
        }
    }

    // MARK: - Cancellation

    /// Removes the reminder of a single dose, for instance once the user marked it as taken.
    static func cancelNotification(for dose: Dose) {
        guard !dose.notificationID.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dose.notificationID])
        // Also clears the banner if the reminder already fired and is sitting in the
        // Notification Center.
        center.removeDeliveredNotifications(withIdentifiers: [dose.notificationID])
    }

    // MARK: - Helpers

    /// The upcoming doses that still need a reminder, earliest first.
    private static func upcomingPendingDoses(context: ModelContext) -> [Dose] {
        let now = Date()
        var descriptor = FetchDescriptor<Dose>(
            predicate: #Predicate { $0.scheduledAt > now },
            sortBy: [SortDescriptor(\.scheduledAt, order: .forward)]
        )
        // The status is filtered in memory: comparing a stored enum inside a #Predicate is not
        // reliably supported by SwiftData.
        descriptor.fetchLimit = maxScheduledNotifications * 4

        let doses = (try? context.fetch(descriptor)) ?? []
        return Array(doses.lazy.filter { $0.status == .pending }.prefix(maxScheduledNotifications))
    }

    private static func content(for dose: Dose) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        let name = dose.medication?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.title = name.isEmpty ? "İlaç zamanı" : name

        let dosage = dose.medication?.dosage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.body = dosage.isEmpty ? "İlaç zamanı" : dosage

        content.sound = .default
        return content
    }

    /// Whether the user has granted permission to show reminders.
    private static func isAuthorized(center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
