//
//  Departure.swift
//  CT
//

/// One upcoming departure from a station, for the Home screen's "Next Departures" list.
nonisolated struct Departure: Identifiable, Sendable {
    let tripID: String
    let trainNumber: String
    let trainType: TrainType
    let departureTime: ServiceTime
    let destination: String

    var id: String { tripID }
}
