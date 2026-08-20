//
//  PADSAlertDTO.swift
//  CT
//

/// `GET https://www.caltrain.com/gtfs/api/v1/servicealerts/Caltrain` — Caltrain's
/// own PADS (Passenger Alert Display System) feed, surfaced on caltrain.com/alerts.
/// Undocumented and unauthenticated — not part of 511's Open Data program, found
/// by reading caltrain.com's own minified JS (`populatePADSServiceAlerts`). Kept
/// distinct from `ServiceAlertsResponse` because 511's `servicealerts` feed only
/// relays a subset of what PADS has (confirmed live: PADS carried a weekend
/// service-suspension notice and a boarding reminder while 511 reported zero
/// active alerts). Response is a bare JSON array, not an envelope like 511's, and
/// — unlike 511 — the real message usually lives in `DescriptionText`, with
/// `HeaderText` empty.
nonisolated struct PADSAlertEntity: Decodable, Sendable {
    struct Alert: Decodable, Sendable {
        struct TranslatedString: Decodable, Sendable {
            struct Translation: Decodable, Sendable {
                let Text: String?
                let Language: String?
            }
            let translations: [Translation]?

            var text: String? {
                let value = translations?.first { $0.Language == "en" }?.Text ?? translations?.first?.Text
                return value?.isEmpty == false ? value : nil
            }

            enum CodingKeys: String, CodingKey {
                case translations = "Translation"
            }
        }
        let HeaderText: TranslatedString?
        let DescriptionText: TranslatedString?
        let cause: Int?
        let effect: Int?
    }
    let Id: Int
    let Alert: Alert
}
