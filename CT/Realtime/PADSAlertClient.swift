//
//  PADSAlertClient.swift
//  CT
//

import Foundation

/// Talks directly to caltrain.com's own alerts feed — see `PADSAlertDTO.swift`
/// for why this exists as a source distinct from 511. No API key; this isn't
/// a 511.org endpoint, so it doesn't go through `FiveElevenRealtimeClient`.
actor PADSAlertClient {
    static let shared = PADSAlertClient()

    private static let alertsURL = URL(string: "https://www.caltrain.com/gtfs/api/v1/servicealerts/Caltrain")!
    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    func alerts() async throws -> [PADSAlertEntity] {
        let (data, response) = try await session.data(from: Self.alertsURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RealtimeError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode([PADSAlertEntity].self, from: data)
        } catch {
            throw RealtimeError.decodeFailed(String(describing: error))
        }
    }
}
