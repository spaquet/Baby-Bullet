//
//  WidgetSnapshot.swift
//  CT
//

import Foundation
import WidgetKit

nonisolated struct WidgetDepartureSnapshot: Codable, Sendable {
    let trainNumber: String
    let destination: String
    let secondsSinceMidnight: Int
}

nonisolated struct WidgetSnapshot: Codable, Sendable {
    let stationID: String
    let stationName: String
    let serviceDate: String
    let departures: [WidgetDepartureSnapshot]
    let returnStationName: String?
    let returnDepartures: [WidgetDepartureSnapshot]
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.stephanepaquet.CT"
    static let key = "widgetSnapshot"

    static func save(
        station: Station,
        serviceDate: String,
        departures: [WidgetDepartureSnapshot],
        returnStationName: String? = nil,
        returnDepartures: [WidgetDepartureSnapshot] = []
    ) {
        let snapshot = WidgetSnapshot(
            stationID: station.id,
            stationName: station.name,
            serviceDate: serviceDate,
            departures: departures,
            returnStationName: returnStationName,
            returnDepartures: returnDepartures
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
