//
//  Trip.swift
//  CT
//

/// Maps directly to a GTFS `trips.txt` row. Carries fields not yet surfaced
/// in the UI (bike/accessibility) so later features don't need a re-import.
nonisolated struct Trip: Identifiable, Hashable, Sendable {
    let id: String
    let routeID: String
    let serviceID: String
    let headsign: String?
    let directionID: Int
    let shortName: String?
    let bikesAllowed: AccessibilityStatus
    let wheelchairAccessible: AccessibilityStatus
}
