//
//  Platform.swift
//  CT
//

/// A boarding platform (GTFS child stop) belonging to a Station (GTFS parent stop).
nonisolated struct Platform: Identifiable, Hashable, Sendable {
    let id: String
    let stationID: String
    let name: String
    let latitude: Double
    let longitude: Double
    let accessibility: AccessibilityStatus
}
