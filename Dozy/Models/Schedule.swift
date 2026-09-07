//
//  Schedule.swift
//  Dozy
//

import Foundation
import SwiftData

/// How often the doses of a schedule repeat.
enum RepeatRule: Int, Codable, CaseIterable {
    case daily = 0
    case specificWeekdays = 1
    case everyNDays = 2
}

@Model
final class Schedule {
    /// Times of day the medication is taken; only the hour/minute components are relevant.
    var times: [Date] = []
    var repeatRule: RepeatRule = RepeatRule.daily
    /// Weekdays used when `repeatRule` is `.specificWeekdays`, 1 = Sunday ... 7 = Saturday.
    var weekdays: [Int] = []
    /// Interval used when `repeatRule` is `.everyNDays`.
    var intervalDays: Int = 1
    var startDate: Date = Date()
    /// Open ended schedule when `nil`.
    var endDate: Date?

    var medication: Medication?

    init(
        times: [Date] = [],
        repeatRule: RepeatRule = .daily,
        weekdays: [Int] = [],
        intervalDays: Int = 1,
        startDate: Date = Date(),
        endDate: Date? = nil,
        medication: Medication? = nil
    ) {
        self.times = times
        self.repeatRule = repeatRule
        self.weekdays = weekdays
        self.intervalDays = intervalDays
        self.startDate = startDate
        self.endDate = endDate
        self.medication = medication
    }
}
