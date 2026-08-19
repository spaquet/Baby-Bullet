//
//  TripActivityAttributes.swift
//  BabyBulletWidget
//
//  Duplicate of CT/LiveActivity/TripActivityAttributes.swift — keep the two
//  in sync. See that file for why this isn't a shared file.
//

import ActivityKit
import Foundation

struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var delayMinutes: Int?
        var statusLabel: String
        var expectedArrival: Date?
    }

    let tripID: String
    let trainNumber: String
    let originName: String
    let destName: String
    let scheduledDeparture: Date
    let scheduledArrival: Date
}
