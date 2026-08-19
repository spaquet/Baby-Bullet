//
//  RealtimeService.swift
//  CT
//

import Foundation
import CoreLocation

/// App-facing live status: per-stop delay lookups for `StopsSheet` and the
/// service alerts feed for `AlertsView`. Talks to 511.org directly (see
/// CLAUDE.md's Data sources section) — this is the app's only network client.
@Observable
@MainActor
final class RealtimeService {
    private let client = FiveElevenRealtimeClient.shared

    private var vehicleSnapshot: (activities: [MonitoredVehicleActivity], fetchedAt: Date)?
    private let cacheTTL: TimeInterval = 120

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// One cached vehicle snapshot supplies a trip's current and onward calls.
    /// This avoids one 511 request per row in the stop sheet.
    func statuses(tripID: String, stopIDs: [String], finalPlatform: Platform?) async -> (states: [String: TrainRealtimeStatus], arrived: Bool) {
        guard let activity = await vehicleActivity(tripID: tripID) else { return ([:], false) }

        let journey = activity.MonitoredVehicleJourney
        let calls = [journey.MonitoredCall].compactMap { $0 } + (journey.OnwardCalls?.OnwardCall ?? [])
        let location = journey.VehicleLocation
        let latitude = location.flatMap { Double($0.Latitude ?? "") }
        let longitude = location.flatMap { Double($0.Longitude ?? "") }
        var states: [String: TrainRealtimeStatus] = [:]
        for call in calls {
            guard let stopID = call.StopPointRef, stopIDs.contains(stopID) else { continue }
            states[stopID] = TrainRealtimeStatus(
                tripID: tripID,
                stopID: stopID,
                aimedTime: Self.date(call.AimedDepartureTime ?? call.AimedArrivalTime),
                expectedTime: Self.date(call.ExpectedDepartureTime ?? call.ExpectedArrivalTime),
                vehicleLatitude: latitude,
                vehicleLongitude: longitude,
                recordedAt: Self.date(activity.RecordedAtTime)
            )
        }

        let arrived = journey.MonitoredCall?.StopPointRef == finalPlatform?.id
            && journey.MonitoredCall?.VehicleAtStop?.lowercased() == "true"
            && Self.isAtPlatform(latitude: latitude, longitude: longitude, platform: finalPlatform)
        return (states, arrived)
    }

    private func vehicleActivity(tripID: String) async -> MonitoredVehicleActivity? {
        let activities: [MonitoredVehicleActivity]
        if let vehicleSnapshot, Date().timeIntervalSince(vehicleSnapshot.fetchedAt) < cacheTTL {
            activities = vehicleSnapshot.activities
        } else {
            guard let response = try? await client.vehicleMonitoring() else { return nil }
            activities = response.Siri.ServiceDelivery.VehicleMonitoringDelivery.VehicleActivity ?? []
            vehicleSnapshot = (activities, Date())
        }
        return activities.first {
            $0.MonitoredVehicleJourney.FramedVehicleJourneyRef?.DatedVehicleJourneyRef == tripID
        }
    }

    private static func isAtPlatform(latitude: Double?, longitude: Double?, platform: Platform?) -> Bool {
        guard let latitude, let longitude, let platform else { return false }
        return CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: platform.latitude, longitude: platform.longitude)) <= 150
    }

    /// Currently active alerts. Throws only on a genuine fetch failure — an
    /// empty result means 511 reported zero active alerts, not an error.
    func alerts() async throws -> [ServiceAlert] {
        let response = try await client.serviceAlerts()
        return (response.Entities ?? []).compactMap { entity in
            guard let alert = entity.alert, let header = alert.headerText?.text else { return nil }
            return ServiceAlert(
                id: entity.id ?? header,
                headerText: header,
                descriptionText: alert.descriptionText?.text,
                effect: alert.effect,
                cause: alert.cause
            )
        }
    }

    private static func date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return isoFormatter.date(from: string)
    }
}
