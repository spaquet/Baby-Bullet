//
//  AlertsView.swift
//  CT
//

import SwiftUI

/// Live service alerts, fetched directly from 511.org's real-time API (see
/// CLAUDE.md's Data sources section) via RealtimeService.
struct AlertsView: View {
    @Environment(RealtimeService.self) private var realtimeService
    @State private var alerts: [ServiceAlert] = []
    @State private var loadFailed = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Service Alerts")
                .task { await load() }
                .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
        } else if loadFailed {
            ContentUnavailableView(
                "Couldn't Load Alerts",
                systemImage: "wifi.slash",
                description: Text("Pull to refresh to try again.")
            )
        } else if alerts.isEmpty {
            ContentUnavailableView(
                "No Alerts",
                systemImage: "checkmark.circle",
                description: Text("There are no active Caltrain service alerts right now.")
            )
        } else {
            List(alerts) { alert in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.headerText)
                        .font(.system(size: 15, weight: .semibold))
                    if let description = alert.descriptionText {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func load() async {
        isLoading = alerts.isEmpty
        do {
            alerts = try await realtimeService.alerts()
            loadFailed = false
        } catch {
            loadFailed = alerts.isEmpty
        }
        isLoading = false
    }
}
