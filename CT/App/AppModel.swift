//
//  AppModel.swift
//  CT
//

import Foundation

enum OnboardingStage: Sendable {
    case welcome
    case locationPermission
    case main
}

/// Root app state: onboarding progress and the user's saved preferences.
/// Screen-local state (sheet visibility, form fields) lives in each view.
@Observable
@MainActor
final class AppModel {
    private(set) var stage: OnboardingStage = .welcome
    private(set) var stations: [Station] = []
    private(set) var homeStationID: String?
    private(set) var workStationID: String?
    private(set) var locationEnabled = false
    private(set) var notificationsEnabled = false
    private(set) var trackedTrip: TrackedTrip?
    private(set) var dataVersion: Int = 1
    private(set) var dataSyncedAt: Date?

    let db = CTDatabase.shared
    let locationService = LocationService()
    let realtimeService: RealtimeService
    let trackedTripCoordinator: TrackedTripCoordinator

    init(realtimeService: RealtimeService) {
        self.realtimeService = realtimeService
        self.trackedTripCoordinator = TrackedTripCoordinator()
    }

    var homeStation: Station? {
        stations.first { $0.id == homeStationID }
    }

    var workStation: Station? {
        stations.first { $0.id == workStationID }
    }

    func bootstrap() async {
        do {
            try await db.open()
            stations = try await db.stations()
            let prefs = try await db.preferences()
            homeStationID = prefs.homeStationID ?? stations.first { $0.id == "palo_alto" }?.id ?? stations.first?.id
            workStationID = prefs.workStationID
            locationEnabled = prefs.locationEnabled
            notificationsEnabled = prefs.notificationsEnabled
            stage = prefs.onboardingComplete ? .main : .welcome
            if locationEnabled { locationService.requestAuthorization() }
            await updateWidgetSnapshot()
            await loadTrackedTrip()
            await refreshDataSyncInfo()
            Task {
                await RemoteDataUpdater.shared.checkForUpdateIfDue()
                await refreshDataSyncInfo()
            }
        } catch {
            // Bundled DB should always be present and valid; surface loudly in dev.
            assertionFailure("Failed to bootstrap database: \(error)")
        }
    }

    func continueFromWelcome() {
        stage = .locationPermission
    }

    func allowLocation() {
        locationEnabled = true
        locationService.requestAuthorization()
        finishOnboarding()
    }

    func skipLocation() {
        locationEnabled = false
        finishOnboarding()
    }

    private func finishOnboarding() {
        stage = .main
        Task {
            try? await db.setLocationEnabled(locationEnabled)
            try? await db.setOnboardingComplete(true)
        }
    }

    func setHomeStation(_ station: Station) {
        homeStationID = station.id
        Task {
            try? await db.setHomeStation(station.id)
            await updateWidgetSnapshot()
        }
    }

    func setLocationEnabled(_ enabled: Bool) {
        locationEnabled = enabled
        if enabled { locationService.requestAuthorization() }
        Task { try? await db.setLocationEnabled(enabled) }
    }

    func setWorkStation(_ station: Station?) {
        workStationID = station?.id
        Task {
            try? await db.setWorkStation(station?.id)
            await updateWidgetSnapshot()
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        Task {
            let granted = enabled ? await TripNotificationScheduler.shared.requestAuthorization() : true
            notificationsEnabled = enabled && granted
            try? await db.setNotificationsEnabled(notificationsEnabled)
        }
    }

    // MARK: - Tracked trip

    private func loadTrackedTrip() async {
        guard let trip = try? await db.trackedTrip() else { return }
        guard trip.serviceDate == serviceDateString() else {
            try? await db.clearTrackedTrip()
            return
        }
        trackedTrip = trip
        trackedTripCoordinator.resume(appModel: self, with: trip)
    }

    func track(_ result: TripResult) {
        guard let origin = result.stops.first, let dest = result.stops.last else { return }
        let trip = TrackedTrip(
            tripID: result.tripID,
            trainNumber: result.trainNumber,
            serviceDate: serviceDateString(),
            originStopID: origin.stopID,
            originName: origin.stationName,
            destStopID: dest.stopID,
            destName: dest.stationName,
            state: .upcoming,
            createdAt: .now
        )
        trackedTrip = trip
        Task { try? await db.setTrackedTrip(trip) }
        trackedTripCoordinator.start(appModel: self, with: trip, departureTime: result.departureTime, arrivalTime: result.arrivalTime)
    }

    func setTrackedTripState(_ state: TrackedTrip.State) {
        trackedTrip?.state = state
    }

    func untrack() {
        trackedTrip = nil
        Task { try? await db.clearTrackedTrip() }
        trackedTripCoordinator.stop()
    }

    /// Called on scene-phase foreground re-entry — the coordinator's own
    /// state machine only advances while running, so this re-derives state
    /// after any time spent backgrounded.
    func reconcileTrackedTrip() {
        trackedTripCoordinator.reconcile()
    }

    /// The station to feature on Home: nearest known station if location is
    /// on and we have a fix, otherwise the saved home station.
    var featuredStation: Station? {
        if locationEnabled, let coordinate = locationService.currentCoordinate {
            return stations.min { lhs, rhs in
                coordinate.distanceSquared(to: lhs) < coordinate.distanceSquared(to: rhs)
            }
        }
        return homeStation
    }

    var isUsingNearestStation: Bool {
        locationEnabled && locationService.currentCoordinate != nil
    }

    private func updateWidgetSnapshot() async {
        guard let homeStation,
              let active = try? await db.activeServices(on: .now)
        else { return }
        let departures: [WidgetDepartureSnapshot]
        let returnDepartures: [WidgetDepartureSnapshot]
        if let workStation, workStation != homeStation {
            departures = ((try? await db.tripResults(
                originStationID: homeStation.id,
                destinationStationID: workStation.id,
                serviceIDs: active.serviceIDs
            )) ?? [])
            .filter { $0.departureTime >= currentServiceTime() }
            .map { WidgetDepartureSnapshot(trainNumber: $0.trainNumber, destination: workStation.name, secondsSinceMidnight: $0.departureTime.secondsSinceMidnight) }
            returnDepartures = ((try? await db.tripResults(
                originStationID: workStation.id,
                destinationStationID: homeStation.id,
                serviceIDs: active.serviceIDs
            )) ?? [])
            .filter { $0.departureTime >= currentServiceTime() }
            .map { WidgetDepartureSnapshot(trainNumber: $0.trainNumber, destination: homeStation.name, secondsSinceMidnight: $0.departureTime.secondsSinceMidnight) }
        } else {
            departures = ((try? await db.departures(
                fromStationID: homeStation.id,
                serviceIDs: active.serviceIDs,
                after: currentServiceTime()
            )) ?? [])
            .map { WidgetDepartureSnapshot(trainNumber: $0.trainNumber, destination: $0.destination, secondsSinceMidnight: $0.departureTime.secondsSinceMidnight) }
            returnDepartures = []
        }
        WidgetSnapshotStore.save(
            station: homeStation,
            serviceDate: serviceDateString(),
            departures: departures,
            returnStationName: workStation?.name,
            returnDepartures: returnDepartures
        )
    }

    private func currentServiceTime() -> ServiceTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return ServiceTime(secondsSinceMidnight: (components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60)
    }

    private func refreshDataSyncInfo() async {
        dataVersion = (try? await db.dataVersion()) ?? dataVersion
        dataSyncedAt = try? await db.dataSyncedAt()
    }

    func serviceDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: .now)
    }
}
