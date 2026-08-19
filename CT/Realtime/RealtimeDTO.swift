//
//  RealtimeDTO.swift
//  CT
//
//  Codable shapes for 511.org's real-time transit JSON responses. Captured
//  live against api.511.org before writing these — note the two SIRI
//  endpoints wrap their payload differently (VehicleMonitoring has a "Siri"
//  envelope, StopMonitoring does not), so they're modeled as distinct types
//  rather than forced into a shared envelope.
//

/// `GET /transit/StopMonitoring` — predictions/delay for one stop.
nonisolated struct StopMonitoringResponse: Decodable, Sendable {
    struct ServiceDelivery: Decodable, Sendable {
        let StopMonitoringDelivery: StopMonitoringDelivery
    }
    struct StopMonitoringDelivery: Decodable, Sendable {
        let MonitoredStopVisit: [MonitoredStopVisit]?
    }
    let ServiceDelivery: ServiceDelivery
}

/// `GET /transit/VehicleMonitoring` — live position/delay for all vehicles.
nonisolated struct VehicleMonitoringResponse: Decodable, Sendable {
    struct Siri: Decodable, Sendable {
        let ServiceDelivery: ServiceDelivery
    }
    struct ServiceDelivery: Decodable, Sendable {
        let VehicleMonitoringDelivery: VehicleMonitoringDelivery
    }
    struct VehicleMonitoringDelivery: Decodable, Sendable {
        let VehicleActivity: [MonitoredVehicleActivity]?
    }
    let Siri: Siri
}

nonisolated struct MonitoredStopVisit: Decodable, Sendable {
    let RecordedAtTime: String?
    let MonitoringRef: String?
    let MonitoredVehicleJourney: MonitoredVehicleJourney
}

nonisolated struct MonitoredVehicleActivity: Decodable, Sendable {
    let RecordedAtTime: String?
    let MonitoredVehicleJourney: MonitoredVehicleJourney
}

nonisolated struct MonitoredVehicleJourney: Decodable, Sendable {
    struct FramedVehicleJourneyRef: Decodable, Sendable {
        let DataFrameRef: String?
        let DatedVehicleJourneyRef: String?
    }
    struct VehicleLocation: Decodable, Sendable {
        let Longitude: String?
        let Latitude: String?
    }
    struct MonitoredCall: Decodable, Sendable {
        let StopPointRef: String?
        let AimedArrivalTime: String?
        let ExpectedArrivalTime: String?
        let AimedDepartureTime: String?
        let ExpectedDepartureTime: String?
        let VehicleAtStop: String?
    }

    struct OnwardCalls: Decodable, Sendable {
        let OnwardCall: [MonitoredCall]?
    }

    let FramedVehicleJourneyRef: FramedVehicleJourneyRef?
    let VehicleLocation: VehicleLocation?
    let MonitoredCall: MonitoredCall?
    let OnwardCalls: OnwardCalls?
}

/// `GET /transit/servicealerts` — GTFS-Realtime FeedMessage, JSON-serialized.
/// `Entities` was empty in every live sample pulled so far (no active alert
/// to model against), so `Alert`'s fields are all optional and a bad entity
/// is dropped rather than failing the whole decode — see
/// `FiveElevenRealtimeClient.decode`.
nonisolated struct ServiceAlertsResponse: Decodable, Sendable {
    struct Header: Decodable, Sendable {
        let GtfsRealtimeVersion: String?
        let Timestamp: Int?
    }
    struct Entity: Decodable, Sendable {
        let id: String?
        let alert: Alert?
    }
    struct Alert: Decodable, Sendable {
        struct TranslatedString: Decodable, Sendable {
            struct Translation: Decodable, Sendable {
                let text: String?
                let language: String?
            }
            let translation: [Translation]?

            var text: String? { translation?.first?.text }
        }
        struct ActivePeriod: Decodable, Sendable {
            let start: Int?
            let end: Int?
        }
        let activePeriod: [ActivePeriod]?
        let cause: String?
        let effect: String?
        let headerText: TranslatedString?
        let descriptionText: TranslatedString?
        let url: TranslatedString?
    }
    let Header: Header?
    let Entities: [Entity]?
}
