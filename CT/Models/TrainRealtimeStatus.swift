//
//  TrainRealtimeStatus.swift
//  CT
//

import Foundation

/// Live delay/position for one trip at one stop, from 511's real-time API.
/// 511 only reports vehicles currently active in its system — a trip whose
/// service day has fully ended may simply have no data any more.
nonisolated struct TrainRealtimeStatus: Sendable {
    let tripID: String
    let stopID: String
    let aimedTime: Date?
    let expectedTime: Date?
    let vehicleLatitude: Double?
    let vehicleLongitude: Double?
    let recordedAt: Date?

    /// Positive = late, negative = early, nil = 511 gave no prediction to compare.
    var delayMinutes: Int? {
        guard let aimedTime, let expectedTime else { return nil }
        return Int((expectedTime.timeIntervalSince(aimedTime) / 60).rounded())
    }
}
