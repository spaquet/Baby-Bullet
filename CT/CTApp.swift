//
//  CTApp.swift
//  CT
//
//  Created by Stéphane PAQUET on 8/19/26.
//

import SwiftUI

@main
struct CTApp: App {
    @State private var appModel = AppModel()
    @State private var realtimeService = RealtimeService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(realtimeService)
        }
    }
}
