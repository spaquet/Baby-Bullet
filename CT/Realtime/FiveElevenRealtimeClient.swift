//
//  FiveElevenRealtimeClient.swift
//  CT
//

import Foundation

/// Talks to 511.org's real-time transit API directly from the device (see
/// CLAUDE.md's Data sources section). Always `format=json`, agency `CT`.
actor FiveElevenRealtimeClient {
    static let shared = FiveElevenRealtimeClient()

    private static let baseURL = "https://api.511.org/transit"
    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    func stopMonitoring(stopID: String) async throws -> StopMonitoringResponse {
        try await get("StopMonitoring", extra: ["stopcode": stopID])
    }

    func vehicleMonitoring() async throws -> VehicleMonitoringResponse {
        try await get("VehicleMonitoring")
    }

    func serviceAlerts() async throws -> ServiceAlertsResponse {
        try await get("servicealerts")
    }

    private func get<T: Decodable>(_ path: String, extra: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(Self.baseURL)/\(path)")
        var items = [
            URLQueryItem(name: "api_key", value: Secrets.fiveElevenAPIToken),
            URLQueryItem(name: "agency", value: "CT"),
            URLQueryItem(name: "format", value: "json"),
        ]
        items.append(contentsOf: extra.map { URLQueryItem(name: $0.key, value: $0.value) })
        components?.queryItems = items

        guard let url = components?.url else { throw RealtimeError.invalidURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RealtimeError.httpStatus(http.statusCode)
        }
        return try Self.decode(T.self, from: data)
    }

    /// 511 serves JSON as UTF-8 with a leading BOM — `JSONDecoder` chokes on
    /// it unprompted, same gotcha `scripts/five_eleven.py`'s `parse_json`
    /// already works around with `decode("utf-8-sig")`.
    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        var data = data
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        if data.prefix(3).elementsEqual(bom) {
            data = data.dropFirst(3)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RealtimeError.decodeFailed(String(describing: error))
        }
    }
}
