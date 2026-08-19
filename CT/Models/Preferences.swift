//
//  Preferences.swift
//  CT
//

/// User prefs, stored in the same SQLite file as the timetable data.
nonisolated struct Preferences: Sendable {
    var homeStationID: String?
    var locationEnabled: Bool
    var notificationsEnabled: Bool
    var onboardingComplete: Bool
}
