//
//  TrackedTripCoordinator.swift
//  CT
//

import Foundation

/// Drives the tracked trip's state machine (`upcoming → boarded → ended`),
/// owned by `AppModel`. Time-based, not location-based — see CLAUDE.md-adjacent
/// design notes: there's no sensor signal for "the user boarded," so
/// `boarded` starts at scheduled departure and `ended` follows either the
/// scheduled arrival (+ buffer) or 511 reporting the vehicle has arrived.
///
/// Runs a foreground polling loop only — there's no BGTaskScheduler
/// registration in this project, so state only advances while the app is
/// active. `AppModel.reconcileTrackedTrip()` re-ticks on scene-phase
/// foreground re-entry to catch up after backgrounding. Local notifications
/// (leave-now, delay alerts) still fire independently of this loop.
@Observable
@MainActor
final class TrackedTripCoordinator {
    /// Set on first use (`start`/`resume`) rather than at init — `AppModel`
    /// constructs this coordinator as part of its own init, before `self` is
    /// fully available to hand over.
    private weak var appModel: AppModel?
    private let notificationScheduler = TripNotificationScheduler.shared
    private let liveActivityManager = TripLiveActivityManager()

    private var pollTask: Task<Void, Never>?
    private var departureDate: Date?
    private var arrivalDate: Date?
    private var lastAlertedDelayMinutes: Int?

    private let pollInterval: Duration = .seconds(30)
    private let arrivalGrace: TimeInterval = 5 * 60
    private let leaveNowBuffer: TimeInterval = 10 * 60

    /// Starts tracking a freshly-tracked trip (known departure/arrival times
    /// already in hand from the search result).
    func start(appModel: AppModel, with trip: TrackedTrip, departureTime: ServiceTime, arrivalTime: ServiceTime) {
        self.appModel = appModel
        let departureDate = departureTime.date(onServiceDayOf: .now)
        let arrivalDate = arrivalTime.date(onServiceDayOf: .now)
        self.departureDate = departureDate
        self.arrivalDate = arrivalDate
        lastAlertedDelayMinutes = nil

        if appModel.notificationsEnabled {
            notificationScheduler.scheduleLeaveNow(trip: trip, departureDate: departureDate, buffer: leaveNowBuffer)
        }
        runPollLoop()
    }

    /// Resumes a trip persisted from a previous launch — departure/arrival
    /// times aren't stored, only stop IDs, so look them up.
    func resume(appModel: AppModel, with trip: TrackedTrip) {
        Task {
            guard let stops = try? await appModel.db.stopsForTrip(tripID: trip.tripID),
                  let origin = stops.first(where: { $0.stopID == trip.originStopID }),
                  let dest = stops.first(where: { $0.stopID == trip.destStopID })
            else { return }
            start(appModel: appModel, with: trip, departureTime: origin.time, arrivalTime: dest.time)
        }
    }

    /// Re-runs one state check immediately — called on foreground re-entry.
    func reconcile() {
        guard appModel?.trackedTrip != nil else { return }
        Task { await tick() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        notificationScheduler.cancelAll()
        liveActivityManager.end()
        departureDate = nil
        arrivalDate = nil
        lastAlertedDelayMinutes = nil
    }

    private func runPollLoop() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.tick()
                try? await Task.sleep(for: self.pollInterval)
            }
        }
    }

    private func tick() async {
        guard let appModel, let trip = appModel.trackedTrip, let departureDate, let arrivalDate else { return }

        switch trip.state {
        case .upcoming:
            if Date.now >= departureDate {
                await transition(appModel, trip, to: .boarded)
                liveActivityManager.start(trip: trip, departureDate: departureDate, arrivalDate: arrivalDate)
            }
        case .boarded:
            await pollRealtime(appModel, trip: trip, arrivalDate: arrivalDate)
        case .ended:
            appModel.untrack()
        }
    }

    private func pollRealtime(_ appModel: AppModel, trip: TrackedTrip, arrivalDate: Date) async {
        if Date.now >= arrivalDate.addingTimeInterval(arrivalGrace) {
            await transition(appModel, trip, to: .ended)
            appModel.untrack()
            return
        }

        let finalPlatform = try? await appModel.db.platform(id: trip.destStopID)
        let live = await appModel.realtimeService.statuses(
            tripID: trip.tripID,
            stopIDs: [trip.originStopID, trip.destStopID],
            finalPlatform: finalPlatform
        )
        if live.arrived {
            await transition(appModel, trip, to: .ended)
            appModel.untrack()
            return
        }

        guard let status = live.states[trip.destStopID] else { return }
        liveActivityManager.update(status)

        if appModel.notificationsEnabled, let delay = status.delayMinutes, delay >= 5, delay != lastAlertedDelayMinutes {
            lastAlertedDelayMinutes = delay
            notificationScheduler.scheduleDelayAlert(trip: trip, delayMinutes: delay)
        }
    }

    private func transition(_ appModel: AppModel, _ trip: TrackedTrip, to state: TrackedTrip.State) async {
        appModel.setTrackedTripState(state)
        try? await appModel.db.setTrackedTripState(state)
    }
}
