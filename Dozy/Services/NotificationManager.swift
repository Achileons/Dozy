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

    /// Tags a request as a low stock warning. Dose reminders are everything else, including
    /// requests left behind by a version that did not tag anything, so a sync started under
    /// the old scheme still clears them.
    private static let lowStockCategory = "lowStock"

    /// When a stock warning is delivered. Not the moment the package ran down — that is
    /// usually mid dose — but the next morning, when there is time to do something about it.
    private static let lowStockHour = 10

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
            await removePendingDoseNotifications(center: center)
            return
        }

        let doses = upcomingPendingDoses(context: context)

        // Drop the dose reminders first so doses that were taken or rescheduled in the
        // meantime cannot leave a stale one behind. Stock warnings are left alone: they are
        // not derived from the doses and would not be rebuilt below.
        await removePendingDoseNotifications(center: center)

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

    // MARK: - Low stock

    /// Brings the stock warning of `medication` in line with what is left in the package: one
    /// pending request while the package is at or below the threshold, none above it.
    ///
    /// These requests are counted separately from the dose reminders and are never touched by
    /// `syncScheduledNotifications`, so a warning cannot be lost to a rebuild.
    static func updateLowStockNotification(for medication: Medication, context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        guard !medication.isArchived, medication.isLowOnStock else {
            cancelLowStockNotification(for: medication, context: context)
            return
        }

        guard await isAuthorized(center: center) else { return }

        // A warning already waiting keeps the date it was first set for. Every later dose
        // only refreshes what it says, so ticking doses off cannot push the warning further
        // out each time and leave it never arriving.
        let existingTrigger = await pendingLowStockTrigger(for: medication, center: center)

        // Reusing the identifier means re-adding the request replaces the one already there,
        // so a package that keeps dropping never stacks up warnings.
        if medication.lowStockNotificationID.isEmpty {
            medication.lowStockNotificationID = UUID().uuidString
            try? context.save()
        }

        guard let trigger = existingTrigger ?? freshLowStockTrigger() else { return }

        let request = UNNotificationRequest(
            identifier: medication.lowStockNotificationID,
            content: lowStockContent(for: medication),
            trigger: trigger
        )

        try? await center.add(request)
    }

    /// Withdraws the warning once the package is refilled, or once the medication is gone.
    static func cancelLowStockNotification(for medication: Medication, context: ModelContext) {
        let identifier = medication.lowStockNotificationID
        guard !identifier.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        medication.lowStockNotificationID = ""
        try? context.save()
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

    /// Every pending request that is not a stock warning, which is what this app schedules
    /// besides them.
    private static func removePendingDoseNotifications(center: UNUserNotificationCenter) async {
        let identifiers = await center.pendingNotificationRequests()
            .filter { $0.content.categoryIdentifier != lowStockCategory }
            .map(\.identifier)

        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// The trigger of the warning already queued for this medication, if there is one. A
    /// request that has already been delivered is no longer pending, so a package that drops
    /// below the threshold again gets a fresh date rather than a date in the past.
    private static func pendingLowStockTrigger(
        for medication: Medication,
        center: UNUserNotificationCenter
    ) async -> UNNotificationTrigger? {
        let identifier = medication.lowStockNotificationID
        guard !identifier.isEmpty else { return nil }

        return await center.pendingNotificationRequests()
            .first { $0.identifier == identifier }?
            .trigger
    }

    /// Tomorrow morning, so a warning raised while taking a dose does not arrive on top of
    /// the reminder for it.
    private static func freshLowStockTrigger() -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let fireDate = calendar.date(
                  bySettingHour: lowStockHour, minute: 0, second: 0, of: tomorrow
              )
        else { return nil }

        return UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            ),
            repeats: false
        )
    }

    private static func lowStockContent(for medication: Medication) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        let name = medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        content.title = name.isEmpty ? "İlaç azalıyor" : "\(name) azalıyor"
        content.body = medication.currentStock > 0
            ? "\(medication.stockText) kaldı"
            : "Stok bitti"

        content.categoryIdentifier = lowStockCategory
        content.sound = .default
        return content
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
