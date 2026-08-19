//
//  Station.swift
//  CT
//

import Foundation

nonisolated struct Station: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let zoneID: String?
}
