//
//  TrackedTrip.swift
//  CT
//

import Foundation

/// The one trip the user has asked to be tracked (Live Activity + notifications).
/// Single active row — see CTDatabase's `tracked_trip` table.
nonisolated struct TrackedTrip: Sendable {
    enum State: String, Sendable {
        case upcoming
        case boarded
        case ended
    }

    let tripID: String
    let trainNumber: String
    /// `yyyyMMdd`, America/Los_Angeles — the calendar day this trip runs on,
    /// captured at track-time. Used to detect a stale trip on next launch.
    let serviceDate: String
    let originStopID: String
    let originName: String
    let destStopID: String
    let destName: String
    var state: State
    let createdAt: Date
}
