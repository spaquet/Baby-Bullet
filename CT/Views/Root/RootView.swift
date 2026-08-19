//
//  RootView.swift
//  CT
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appModel.stage {
            case .welcome:
                WelcomeView(onContinue: appModel.continueFromWelcome)
            case .locationPermission:
                LocationPermissionView(onAllow: appModel.allowLocation, onSkip: appModel.skipLocation)
            case .main:
                MainTabView()
            }
        }
        .task { await appModel.bootstrap() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { appModel.reconcileTrackedTrip() }
        }
    }
}
