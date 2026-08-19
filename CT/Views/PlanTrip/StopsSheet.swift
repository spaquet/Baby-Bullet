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
    @Environment(RealtimeService.self) private var realtimeService
    @Environment(\.dismiss) private var dismiss
    @State private var stops: [StopArrival] = []
    @State private var liveStates: [Int: DelayPill.State] = [:]
    @State private var hasArrived = false

    var body: some View {
        NavigationStack {
            List {
                if hasArrived {
                    Label("Arrived at final destination", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                }

                ForEach(stops) { stop in
                    HStack(spacing: 12) {
                        Circle().fill(trainType.badgeColor).frame(width: 8, height: 8)
                        Text(stop.stationName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if !hasArrived {
                            DelayPill(state: liveStates[stop.id] ?? .loading)
                        }
                        Text(stop.time.displayString)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
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
        } else {
            stops = (try? await appModel.db.stopsForTrip(tripID: tripID)) ?? []
        }
        await loadLiveStatuses()
    }

    private func loadLiveStatuses() async {
        guard !stops.isEmpty else { return }
        if scheduledArrivalHasPassed(stops.last!) {
            hasArrived = true
            liveStates = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, .unavailable) })
            return
        }

        let finalPlatform = try? await appModel.db.platform(id: stops.last!.stopID)
        let live = await realtimeService.statuses(
            tripID: tripID,
            stopIDs: stops.map(\.stopID),
            finalPlatform: finalPlatform
        )
        hasArrived = live.arrived
        liveStates = Dictionary(uniqueKeysWithValues: stops.map {
            ($0.id, live.states[$0.stopID].map(DelayPill.State.status) ?? .unavailable)
        })
    }

    private func scheduledArrivalHasPassed(_ finalStop: StopArrival) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: .now)
        let now = ServiceTime(secondsSinceMidnight:
            (components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
        )
        // ponytail: scheduled fallback assumes completion; replace with retained trip updates if history is added.
        return finalStop.time.isAtLeastFiveMinutesPast(now)
    }
}
