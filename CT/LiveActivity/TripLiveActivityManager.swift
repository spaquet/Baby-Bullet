//
//  TripLiveActivityManager.swift
//  CT
//

import ActivityKit
import Foundation

/// Starts/updates/ends the tracked trip's Live Activity. Local updates only
/// (no push/APNs) — driven by the same `RealtimeService` poll already used
/// for delay alerts, so update cadence is throttled by iOS once the app is
/// backgrounded. Owned by `TrackedTripCoordinator`.
@MainActor
final class TripLiveActivityManager {
    private var activity: Activity<TripActivityAttributes>?

    func start(trip: TrackedTrip, departureDate: Date, arrivalDate: Date) {
        guard activity == nil else { return }
        let attributes = TripActivityAttributes(
            tripID: trip.tripID,
            trainNumber: trip.trainNumber,
            originName: trip.originName,
            destName: trip.destName,
            scheduledDeparture: departureDate,
            scheduledArrival: arrivalDate
        )
        let initialState = TripActivityAttributes.ContentState(
            delayMinutes: nil,
            statusLabel: "On time",
            expectedArrival: arrivalDate
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil)
        )
    }

    func update(_ status: TrainRealtimeStatus) {
        guard let activity else { return }
        let delay = status.delayMinutes
        let label: String
        if let delay, delay > 1 {
            label = "Delayed \(delay) min"
        } else if let delay, delay < -1 {
            label = "Early \(-delay) min"
        } else {
            label = "On time"
        }
        let state = TripActivityAttributes.ContentState(
            delayMinutes: delay,
            statusLabel: label,
            expectedArrival: status.expectedTime
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
