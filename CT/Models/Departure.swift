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
    /// Arrival time at the trip's final stop (its terminus, e.g. San
    /// Francisco or Gilroy) — not a user-chosen destination, since Home has
    /// no destination picker.
    let terminusArrivalTime: ServiceTime

    var id: String { tripID }

    var rideDurationMinutes: Int {
        (terminusArrivalTime.secondsSinceMidnight - departureTime.secondsSinceMidnight) / 60
    }
}
