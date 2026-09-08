//
//  StockCalculator.swift
//  Dozy
//

import Foundation

/// Works out how fast a medication is used up, and how long what is left will last.
enum StockCalculator {

    /// Average number of units taken per day, across every schedule the medication carries.
    /// Averaged rather than exact: a weekday rule is spread over the week, so three days out
    /// of seven reads as a fraction of a dose per day rather than as a run of empty days.
    ///
    /// Returns `nil` when nothing is scheduled, since a rate of zero has no meaning here and
    /// dividing by it later would not either.
    static func dailyConsumption(for medication: Medication) -> Double? {
        let total = (medication.schedules ?? []).reduce(0) { running, schedule in
            running + dailyConsumption(for: schedule, amount: medication.dosageAmount)
        }

        return total > 0 ? total : nil
    }

    /// Whole days the current package covers at the average rate. Rounded down, so the
    /// number never promises a day the package cannot cover.
    static func daysRemaining(for medication: Medication) -> Int? {
        guard let daily = dailyConsumption(for: medication) else { return nil }
        guard medication.currentStock > 0 else { return 0 }

        return Int((Double(medication.currentStock) / daily).rounded(.down))
    }

    /// The line shown under a medication: what is left, and how long it lasts when that can
    /// be worked out. `nil` when the medication does not track stock at all.
    static func summary(for medication: Medication) -> String? {
        guard medication.stockEnabled else { return nil }
        guard medication.currentStock > 0 else { return "Stok bitti" }

        guard let days = daysRemaining(for: medication) else { return medication.stockText }
        return "\(medication.stockText) · \(days) gün"
    }

    // MARK: - Helpers

    private static func dailyConsumption(for schedule: Schedule, amount: Double) -> Double {
        let perActiveDay = Double(schedule.times.count) * amount
        guard perActiveDay > 0 else { return 0 }

        switch schedule.repeatRule {
        case .daily:
            return perActiveDay

        case .specificWeekdays:
            return perActiveDay * Double(schedule.weekdays.count) / 7

        case .everyNDays:
            return perActiveDay / Double(max(1, schedule.intervalDays))
        }
    }
}
