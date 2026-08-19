//
//  TripNotificationScheduler.swift
//  CT
//

import Foundation
import UserNotifications

/// Local (device-only, no APNs) notifications for the tracked trip: a
/// leave-now reminder ahead of scheduled departure, and delay alerts fired
/// as 511 reports them. Owned indirectly via `TrackedTripCoordinator`.
@MainActor
final class TripNotificationScheduler {
    static let shared = TripNotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Requests alert/sound authorization. Returns whether the app is
    /// actually authorized afterward — including the case where the user had
    /// already granted or denied it in a previous session.
    func requestAuthorization() async -> Bool {
        if let granted = try? await center.requestAuthorization(options: [.alert, .sound]) {
            return granted
        }
        return false
    }

    func scheduleLeaveNow(trip: TrackedTrip, departureDate: Date, buffer: TimeInterval) {
        let fireDate = departureDate.addingTimeInterval(-buffer)
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to leave"
        content.body = "Your train leaves in \(Int(buffer / 60)) min."
        content.sound = .default

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.leaveNowID(tripID: trip.tripID, serviceDate: trip.serviceDate), content: content, trigger: trigger)
        center.add(request)
    }

    /// Fires immediately — called when the coordinator detects a meaningful
    /// delay change while the trip is `boarded`.
    func scheduleDelayAlert(trip: TrackedTrip, delayMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Delay update"
        content.body = "Your train is running \(delayMinutes) min late."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.delayAlertID(tripID: trip.tripID, serviceDate: trip.serviceDate),
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private static func leaveNowID(tripID: String, serviceDate: String) -> String {
        "leave-now-\(tripID)-\(serviceDate)"
    }

    private static func delayAlertID(tripID: String, serviceDate: String) -> String {
        "delay-alert-\(tripID)-\(serviceDate)"
    }
}
