//
//  CTApp.swift
//  CT
//
//  Created by Stéphane PAQUET on 8/19/26.
//

import SwiftUI

@main
struct CTApp: App {
    @State private var realtimeService = RealtimeService()
    @State private var appModel: AppModel

    init() {
        let realtimeService = RealtimeService()
        _realtimeService = State(initialValue: realtimeService)
        _appModel = State(initialValue: AppModel(realtimeService: realtimeService))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(realtimeService)
        }
    }
}
