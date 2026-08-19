//
//  ServiceTime.swift
//  CT
//

import Foundation

/// A GTFS time-of-day: seconds since midnight of the service day, which can
/// exceed 86400 for trips scheduled past midnight (GTFS convention).
nonisolated struct ServiceTime: Sendable, Comparable, Hashable {
    let secondsSinceMidnight: Int

    init(secondsSinceMidnight: Int) {
        self.secondsSinceMidnight = secondsSinceMidnight
    }

    /// Parses a GTFS `H:MM:SS` (or `HH:MM:SS`) string.
    init?(gtfsString: String) {
        let parts = gtfsString.split(separator: ":")
        guard parts.count == 3,
              let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2])
        else { return nil }
        secondsSinceMidnight = h * 3600 + m * 60 + s
    }

    static func < (lhs: ServiceTime, rhs: ServiceTime) -> Bool {
        lhs.secondsSinceMidnight < rhs.secondsSinceMidnight
    }

    /// Displayable "H:mm" in 24-hour time, wrapped to a 24h clock.
    var displayString: String {
        let wrapped = secondsSinceMidnight % 86400
        let h = wrapped / 3600
        let m = (wrapped % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    /// Signed minutes from `reference` to this time — negative once it's past.
    func minutesFromNow(_ reference: ServiceTime) -> Int {
        (secondsSinceMidnight - reference.secondsSinceMidnight) / 60
    }

    func isAtLeastFiveMinutesPast(_ reference: ServiceTime) -> Bool {
        reference.secondsSinceMidnight >= secondsSinceMidnight + 5 * 60
    }

    static func minutesLabel(forMinutes mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60)h \(mins % 60)m"
    }
}
