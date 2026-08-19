//
//  AlertsView.swift
//  CT
//

import SwiftUI

/// Placeholder until the live status/alerts backend exists (see CLAUDE.md —
/// alerts come from our own backend, never fetched directly from 511.org).
struct AlertsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Alerts Yet",
                systemImage: "exclamationmark.triangle",
                description: Text("Service alerts will appear here once live status is available.")
            )
            .navigationTitle("Service Alerts")
        }
    }
}
