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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(stations) { station in
                Button {
                    onPick(station)
                    dismiss()
                } label: {
                    HStack {
                        Text(station.name)
                            .foregroundStyle(.primary)
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
