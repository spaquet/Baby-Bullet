//
//  StationDetailView.swift
//  CT
//

import SwiftUI
import MapKit

/// How far into the past to still show a departure — a train can run late,
/// so don't drop it from the list the instant its scheduled time passes.
private let lateGraceMinutes = 40

struct StationDetailView: View {
    let station: Station
    @Environment(AppModel.self) private var appModel
    @State private var departures: [Departure] = []
    @State private var platforms: [Platform] = []
    @State private var openDeparture: Departure?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let accessibilityNote {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "figure.roll.runningpace")
                                .foregroundStyle(Color("Warning"))
                                .padding(.top, 1)
                            Text(accessibilityNote)
                                .font(.system(size: 14.5))
                                .foregroundStyle(.primary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("WarningBackground"), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    HStack {
                        Text("TODAY'S DEPARTURES")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        if departures.isEmpty {
                            Text("No more scheduled departures today.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .padding(16)
                        } else {
                            ForEach(Array(departures.enumerated()), id: \.element.id) { index, departure in
                                let minutes = departure.departureTime.minutesFromNow(currentServiceTime())
                                Button {
                                    openDeparture = departure
                                } label: {
                                    DepartureRow(
                                        trainNumber: departure.trainNumber, trainType: departure.trainType,
                                        time: departure.departureTime, destination: departure.destination,
                                        rideDurationMinutes: departure.rideDurationMinutes, isPast: minutes < 0
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(departure.id)
                                if index < departures.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openInMaps()
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .sheet(item: $openDeparture) { departure in
                StopsSheet(tripID: departure.tripID, trainNumber: departure.trainNumber, trainType: departure.trainType)
            }
            .task {
                await load()
                centerOnNow(proxy)
            }
        }
    }

    private var accessibilityNote: String? {
        guard platforms.contains(where: { $0.accessibility == .unavailable }) else { return nil }
        return "One or more platforms at \(station.name) are not wheelchair accessible."
    }

    private func currentServiceTime() -> ServiceTime {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let seconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
        return ServiceTime(secondsSinceMidnight: seconds)
    }

    private func load() async {
        do {
            platforms = try await appModel.db.platforms(stationID: station.id)
            let active = try await appModel.db.activeServices(on: Date())
            let now = currentServiceTime()
            let windowStart = ServiceTime(secondsSinceMidnight: max(0, now.secondsSinceMidnight - lateGraceMinutes * 60))
            departures = try await appModel.db.departures(
                fromStationID: station.id, serviceIDs: active.serviceIDs, after: windowStart
            )
        } catch {
            departures = []
        }
    }

    /// Scrolls so the next upcoming (or just-departed) train sits mid-screen,
    /// instead of opening at the top of the whole day's list.
    private func centerOnNow(_ proxy: ScrollViewProxy) {
        let now = currentServiceTime()
        guard let target = departures.first(where: { $0.departureTime >= now }) ?? departures.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                proxy.scrollTo(target.id, anchor: .center)
            }
        }
    }

    private func openInMaps() {
        let location = CLLocation(latitude: station.latitude, longitude: station.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = station.name
        item.openInMaps()
    }
}
