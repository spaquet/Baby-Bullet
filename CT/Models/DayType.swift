//
//  DayType.swift
//  CT
//

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
}
