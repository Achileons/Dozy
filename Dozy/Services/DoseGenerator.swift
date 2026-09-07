//
//  DoseGenerator.swift
//  Dozy
//

import Foundation
import SwiftData

/// Creates the concrete `Dose` records a `Schedule` implies for a given date range.
enum DoseGenerator {

    /// How far ahead doses are materialised when a schedule changes.
    static let regenerationHorizonInDays = 60

    // MARK: - Generation

    /// Creates the doses `schedule` implies between `startDate` and `endDate` (both inclusive,
    /// compared by day). Days that already hold a dose for the same medication and the same
    /// point in time are left untouched, so calling this repeatedly is safe.
    ///
    /// The caller is responsible for saving `context`.
    static func generateDoses(
        for schedule: Schedule,
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) {
        guard let medication = schedule.medication else { return }
        guard !schedule.times.isEmpty else { return }

        // Rules that can never produce a dose.
        switch schedule.repeatRule {
        case .daily:
            break
        case .specificWeekdays:
            guard !schedule.weekdays.isEmpty else { return }
        case .everyNDays:
            guard schedule.intervalDays >= 1 else { return }
        }

        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: endDate)
        guard firstDay <= lastDay else { return }

        // Existing doses of this medication, keyed by whole second, to detect duplicates.
        var takenSlots = Set<Int>()
        for dose in medication.doses ?? [] where !dose.isDeleted {
            takenSlots.insert(slotKey(for: dose.scheduledAt))
        }

        var day = firstDay
        while day <= lastDay {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? .distantFuture }

            guard isActive(schedule, on: day, calendar: calendar) else { continue }

            for time in schedule.times {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                guard let scheduledAt = calendar.date(
                    bySettingHour: components.hour ?? 0,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: day
                ) else { continue }

                let slot = slotKey(for: scheduledAt)
                guard !takenSlots.contains(slot) else { continue }
                takenSlots.insert(slot)

                let dose = Dose(
                    scheduledAt: scheduledAt,
                    status: .pending,
                    notificationID: UUID().uuidString,
                    medication: medication
                )
                context.insert(dose)
            }
        }
    }

    /// Rebuilds the upcoming doses of `schedule` after it was edited: every still pending dose
    /// from today onwards is dropped and regenerated, while doses the user already acted on
    /// (`.taken` / `.skipped`) are kept as history.
    ///
    /// The caller is responsible for saving `context`.
    static func regenerateFutureDoses(for schedule: Schedule, context: ModelContext) {
        guard let medication = schedule.medication else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dose in medication.doses ?? []
        where !dose.isDeleted && dose.status == .pending && dose.scheduledAt >= today {
            context.delete(dose)
        }

        guard let horizon = calendar.date(
            byAdding: .day,
            value: regenerationHorizonInDays,
            to: today
        ) else { return }

        generateDoses(for: schedule, from: today, to: horizon, context: context)
    }

    // MARK: - Helpers

    /// Whether `schedule` asks for doses on `day`, which is expected to be a start of day.
    private static func isActive(_ schedule: Schedule, on day: Date, calendar: Calendar) -> Bool {
        let scheduleStart = calendar.startOfDay(for: schedule.startDate)
        guard day >= scheduleStart else { return false }

        if let endDate = schedule.endDate, day > calendar.startOfDay(for: endDate) {
            return false
        }

        switch schedule.repeatRule {
        case .daily:
            return true

        case .specificWeekdays:
            let weekday = calendar.component(.weekday, from: day)
            return schedule.weekdays.contains(weekday)

        case .everyNDays:
            guard schedule.intervalDays >= 1 else { return false }
            guard let elapsedDays = calendar.dateComponents(
                [.day],
                from: scheduleStart,
                to: day
            ).day else { return false }
            return elapsedDays % schedule.intervalDays == 0
        }
    }

    /// Collapses a date to whole seconds so doses read back from the store compare equal to
    /// freshly built ones.
    private static func slotKey(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate.rounded())
    }
}
