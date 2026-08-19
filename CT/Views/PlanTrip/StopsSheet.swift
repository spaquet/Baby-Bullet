//
//  StopsSheet.swift
//  CT
//

import SwiftUI

/// Stop-by-stop detail for one trip. Pass `preloadedStops` when the caller
/// already has the relevant slice (e.g. a planned origin→destination trip
/// result); otherwise the full remaining route is loaded from `tripID`.
struct StopsSheet: View {
    let tripID: String
    let trainNumber: String
    let trainType: TrainType
    var preloadedStops: [StopArrival]?

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var stops: [StopArrival] = []

    var body: some View {
        NavigationStack {
            List(stops) { stop in
                HStack(spacing: 12) {
                    Circle().fill(trainType.badgeColor).frame(width: 8, height: 8)
                    Text(stop.stationName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(stop.time.displayString)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("\(trainNumber) · \(trainType.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.large, .fraction(0.78)])
    }

    private func load() async {
        if let preloadedStops {
            stops = preloadedStops
            return
        }
        stops = (try? await appModel.db.stopsForTrip(tripID: tripID)) ?? []
    }
}
