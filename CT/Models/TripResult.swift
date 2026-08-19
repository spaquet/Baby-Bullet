//
//  TripResult.swift
//  CT
//

/// One matching train for a planned origin → destination search.
nonisolated struct TripResult: Identifiable, Sendable {
    let tripID: String
    let trainNumber: String
    let trainType: TrainType
    let departureTime: ServiceTime
    let arrivalTime: ServiceTime
    let stops: [StopArrival]

    var id: String { tripID }

    var durationMinutes: Int {
        (arrivalTime.secondsSinceMidnight - departureTime.secondsSinceMidnight) / 60
    }

    var durationLabel: String {
        ServiceTime.minutesLabel(forMinutes: durationMinutes)
    }
}
