//
//  ServiceAlert.swift
//  CT
//

/// One active service alert, from 511's real-time GTFS-Realtime feed.
nonisolated struct ServiceAlert: Identifiable, Sendable {
    let id: String
    let headerText: String
    let descriptionText: String?
    let effect: String?
    let cause: String?
}
