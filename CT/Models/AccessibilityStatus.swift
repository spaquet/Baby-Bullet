//
//  AccessibilityStatus.swift
//  CT
//

/// GTFS's shared 0/1/2 convention: unknown/available/unavailable. Used for
/// `wheelchair_boarding` (stop), `wheelchair_accessible` (trip), and
/// `bikes_allowed` (trip) — same encoding, different subject.
nonisolated enum AccessibilityStatus: Int, Sendable {
    case unknown = 0
    case available = 1
    case unavailable = 2

    init(gtfsValue: Int) {
        self = AccessibilityStatus(rawValue: gtfsValue) ?? .unknown
    }
}
