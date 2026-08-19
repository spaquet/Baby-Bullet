//
//  Route.swift
//  CT
//

/// Maps directly to a GTFS `routes.txt` row.
nonisolated struct Route: Identifiable, Hashable, Sendable {
    let id: String
    let shortName: String
    let longName: String?
    let colorHex: String?
    let textColorHex: String?

    var trainType: TrainType { TrainType(routeShortName: shortName) }
}
