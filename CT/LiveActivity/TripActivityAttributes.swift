//
//  TripActivityAttributes.swift
//  CT
//
//  Duplicated verbatim in the BabyBulletWidget target (same precedent as
//  WidgetSnapshot's Snapshot/Departure structs) — this project's Xcode 16
//  synced folder groups don't share files across targets, so app and widget
//  extension each need their own copy of the ActivityKit contract.
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
