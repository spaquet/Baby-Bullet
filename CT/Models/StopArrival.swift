//
//  StopArrival.swift
//  CT
//

/// One stop along a trip's route, for the trip's stop-by-stop sheet.
nonisolated struct StopArrival: Identifiable, Sendable {
    let stationName: String
    let stopID: String
    let time: ServiceTime
    let stopSequence: Int
    let headsign: String?

    var id: Int { stopSequence }
}
