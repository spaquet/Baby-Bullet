//
//  HomeView.swift
//  CT
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var departures: [Departure] = []
    @State private var isHolidayToday = false
    @State private var scheduleNote: String?
    @State private var planTripPresented = false
    @State private var openDeparture: Departure?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isHolidayToday {
                        HolidayBanner().padding(.horizontal, 16).padding(.bottom, 12)
                    }

                    if let station = appModel.featuredStation {
                        NavigationLink(value: station) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appModel.isUsingNearestStation ? "NEAREST STATION" : "HOME STATION")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(station.name)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    Button {
                        planTripPresented = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Plan a Trip")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Find trains between any two stations")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    HStack {
                        Text("NEXT DEPARTURES")
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
                                Button {
                                    openDeparture = departure
                                } label: {
                                    DepartureRow(
                                        trainNumber: departure.trainNumber, trainType: departure.trainType,
                                        time: departure.departureTime, destination: departure.destination,
                                        minutesUntil: departure.departureTime.minutesUntil(currentServiceTime())
                                    )
                                }
                                .buttonStyle(.plain)
                                if index < departures.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)

                    if let scheduleNote {
                        Text(scheduleNote)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 32)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Baby Bullet")
            .navigationDestination(for: Station.self) { station in
                StationDetailView(station: station)
            }
            .sheet(isPresented: $planTripPresented) {
                PlanTripSheet()
            }
            .sheet(item: $openDeparture) { departure in
                StopsSheet(tripID: departure.tripID, trainNumber: departure.trainNumber, trainType: departure.trainType)
            }
            .task(id: appModel.featuredStation?.id) {
                await load()
            }
        }
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
        guard let station = appModel.featuredStation else { return }
        do {
            let active = try await appModel.db.activeServices(on: Date())
            isHolidayToday = active.isHoliday
            departures = try await appModel.db.departures(
                fromStationID: station.id, serviceIDs: active.serviceIDs, after: currentServiceTime(), limit: 8
            )
            if let nonHolidayID = active.serviceIDs.subtracting(active.holidayOnlyServiceIDs).first {
                scheduleNote = try await appModel.db.calendarDescription(for: nonHolidayID)
            } else {
                scheduleNote = nil
            }
        } catch {
            departures = []
        }
    }
}
