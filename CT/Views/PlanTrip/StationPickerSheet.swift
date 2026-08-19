//
//  StationPickerSheet.swift
//  CT
//

import SwiftUI

struct StationPickerSheet: View {
    let title: String
    let stations: [Station]
    let selectedID: String?
    let onPick: (Station) -> Void
    /// Stations with no service on the currently chosen schedule (e.g. South
    /// County stations on a weekend) — shown, but visually called out rather
    /// than hidden, so the user understands why a search might come up empty.
    var inactiveStationIDs: Set<String> = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(stations) { station in
                let isInactive = inactiveStationIDs.contains(station.id)
                Button {
                    onPick(station)
                    dismiss()
                } label: {
                    HStack {
                        Text(station.name)
                            .foregroundStyle(isInactive ? .secondary : .primary)
                        if isInactive {
                            Text("Not on this schedule")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color("Warning"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color("WarningBackground"), in: Capsule())
                        }
                        Spacer()
                        if station.id == selectedID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large, .fraction(0.78)])
    }
}
