//
//  MainTabView.swift
//  CT
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Routes", systemImage: "train.side.front.car") {
                HomeView()
            }
            Tab("Alerts", systemImage: "exclamationmark.triangle") {
                AlertsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
