//
//  DayType.swift
//  CT
//

import Foundation

/// Which schedule to browse in the trip planner.
nonisolated enum DayType: Sendable, CaseIterable, Hashable {
    case weekday
    case weekend
    case holiday

    var label: String {
        switch self {
        case .weekday: "Weekday"
        case .weekend: "Weekend"
        case .holiday: "Holiday"
        }
    }

    static func defaultRegularSchedule(for date: Date = .now) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return calendar.isDateInWeekend(date) ? .weekend : .weekday
    }
}
