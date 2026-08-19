//
//  SettingsView.swift
//  CT
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var homeStationPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Trip Planning") {
                    Button {
                        homeStationPickerPresented = true
                    } label: {
                        HStack {
                            Label("Home Station", systemImage: "house")
                            Spacer()
                            Text(appModel.homeStation?.name ?? "Not Set")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Toggle(isOn: Binding(
                        get: { appModel.locationEnabled },
                        set: { appModel.setLocationEnabled($0) }
                    )) {
                        Label("Location Services", systemImage: "location")
                    }
                }

                Section("Preferences") {
                    Toggle(isOn: Binding(
                        get: { appModel.notificationsEnabled },
                        set: { appModel.setNotificationsEnabled($0) }
                    )) {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $homeStationPickerPresented) {
                StationPickerSheet(title: "Home Station", stations: appModel.stations, selectedID: appModel.homeStationID) { station in
                    appModel.setHomeStation(station)
                }
            }
        }
    }
}
