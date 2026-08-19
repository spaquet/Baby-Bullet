//
//  HomeView.swift
//  CT
//

import SwiftUI

private enum PickerTarget: Identifiable, Equatable {
    case origin
    case destination
    var id: Self { self }
}

private struct StationDetailTarget: Identifiable {
    let station: Station
    let isRideDestination: Bool

    var id: String { station.id }
}

private struct SearchKey: Equatable {
    let originID: String?
    let destinationID: String?
    let dayType: DayType
}

struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    @State private var originID: String?
    @State private var destinationID: String?
    @State private var dayType: DayType = .weekday
    @State private var holidayServiceIDs: Set<String> = []
    @State private var showHolidayTab = false
    @State private var isHolidayToday = false
    @State private var scheduleNote: String?
    @State private var inactiveStationIDs: Set<String> = []
    @State private var searched = false
    @State private var results: [TripResult] = []
    @State private var pickerTarget: PickerTarget?
    @State private var openResult: TripResult?
    @State private var openStation: StationDetailTarget?

    private var originStation: Station? { appModel.stations.first { $0.id == originID } }
    private var destinationStation: Station? { appModel.stations.first { $0.id == destinationID } }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if isHolidayToday {
                            HolidayBanner().padding(.horizontal, 16).padding(.top, 12)
                        }

                        if !inactiveStationIDs.isEmpty {
                            Text("\(inactiveStationIDs.count) station\(inactiveStationIDs.count == 1 ? "" : "s") don't run on the \(dayType.label.lowercased()) schedule — shown dimmed when picking a station.")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 32)
                                .padding(.top, 12)
                        }

                        if originID != nil, destinationID != nil, originID == destinationID {
                            Text("Choose two different stations.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .padding(.top, 20)
                        } else if searched {
                            resultsList(proxy)
                                .padding(.top, 20)
                        }

                        if let scheduleNote {
                            Text(scheduleNote)
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 32)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        odCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        dayTypePicker
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .background(Color(.systemGroupedBackground))
                }
                .sheet(item: $pickerTarget) { target in
                    StationPickerSheet(
                        title: target == .origin ? "Departing From" : "Arriving At",
                        stations: appModel.stations,
                        selectedID: target == .origin ? originID : destinationID,
                        onPick: { station in
                            if target == .origin { originID = station.id } else { destinationID = station.id }
                        },
                        inactiveStationIDs: inactiveStationIDs
                    )
                }
                .sheet(item: $openResult) { result in
                    StopsSheet(tripID: result.tripID, trainNumber: result.trainNumber, trainType: result.trainType, preloadedStops: result.stops)
                }
                .sheet(item: $openStation) { target in
                    StationDetailView(station: target.station, isRideDestination: target.isRideDestination)
                }
                .task { await prepareDefaults() }
                .task(id: dayType) { await updateInactiveStations() }
                .task(id: SearchKey(originID: originID, destinationID: destinationID, dayType: dayType)) {
                    await search()
                    centerOnNow(proxy)
                }
            }
        }
    }

    private var odCard: some View {
        VStack(spacing: 2) {
            stationRow(label: "FROM", station: originStation, dotColor: Color.accentColor, target: .origin)

            Button {
                swap(&originID, &destinationID)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)

            stationRow(label: "TO", station: destinationStation, dotColor: Color("BadgeExpress"), target: .destination)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func stationRow(label: String, station: Station?, dotColor: Color, target: PickerTarget) -> some View {
        HStack(spacing: 12) {
            Button { pickerTarget = target } label: {
                HStack(spacing: 12) {
                    Circle().fill(dotColor.opacity(0.15)).frame(width: 22, height: 22)
                        .overlay(Circle().fill(dotColor).frame(width: 7, height: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                        Text(station?.name ?? "Choose a station").font(.system(size: 17, weight: .medium)).foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            if let station {
                Button { openStation = StationDetailTarget(station: station, isRideDestination: target == .origin) } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Information about \(station.name)")
            }
        }
        .padding(.vertical, 12)
    }

    private var dayTypePicker: some View {
        Picker("Schedule", selection: $dayType) {
            ForEach(availableDayTypes, id: \.self) { type in
                Text(type.label).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    private var availableDayTypes: [DayType] {
        showHolidayTab ? [.weekday, .weekend, .holiday] : [.weekday, .weekend]
    }

    private func resultsList(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                Text("No trains found for this schedule.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        let isPast = result.departureTime.minutesFromNow(currentServiceTime()) < 0
                        Button {
                            openResult = result
                        } label: {
                            HStack(spacing: 12) {
                                TrainBadge(trainNumber: result.trainNumber, trainType: result.trainType)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(result.departureTime.displayString) – \(result.arrivalTime.displayString)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text("\(result.stops.count) stops")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text(result.durationLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                            .opacity(isPast ? 0.5 : 1)
                            .background(isPast ? Color(.tertiarySystemGroupedBackground) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .id(result.id)
                        if index < results.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
            }
        }
    }

    private func swap(_ a: inout String?, _ b: inout String?) {
        let temp = a
        a = b
        b = temp
    }

    private func currentServiceTime() -> ServiceTime {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let seconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
        return ServiceTime(secondsSinceMidnight: seconds)
    }

    private func prepareDefaults() async {
        if originID == nil { originID = appModel.featuredStation?.id ?? appModel.homeStationID }
        if destinationID == nil {
            destinationID = appModel.stations.first { $0.id != originID }?.id
        }
        if let active = try? await appModel.db.activeServices(on: Date()) {
            isHolidayToday = active.isHoliday
            holidayServiceIDs = active.holidayOnlyServiceIDs
            showHolidayTab = active.isHoliday
            if let nonHolidayID = active.serviceIDs.subtracting(active.holidayOnlyServiceIDs).first {
                scheduleNote = try? await appModel.db.calendarDescription(for: nonHolidayID)
            }
        }
    }

    private func serviceIDs(for dayType: DayType) async -> Set<String> {
        switch dayType {
        case .weekday: return (try? await appModel.db.weekdayServiceIDs()) ?? []
        case .weekend: return (try? await appModel.db.weekendServiceIDs()) ?? []
        case .holiday: return holidayServiceIDs
        }
    }

    private func updateInactiveStations() async {
        let served = (try? await appModel.db.servedStationIDs(serviceIDs: await serviceIDs(for: dayType))) ?? []
        inactiveStationIDs = Set(appModel.stations.map(\.id)).subtracting(served)
    }

    private func search() async {
        guard let originID, let destinationID, originID != destinationID else {
            searched = false
            results = []
            return
        }
        let serviceIDs = await serviceIDs(for: dayType)
        results = (try? await appModel.db.tripResults(originStationID: originID, destinationStationID: destinationID, serviceIDs: serviceIDs)) ?? []
        searched = true
    }

    /// Scrolls so the next upcoming (or just-departed) train sits mid-screen,
    /// instead of opening at the top of the whole day's list.
    private func centerOnNow(_ proxy: ScrollViewProxy) {
        let now = currentServiceTime()
        guard let target = results.first(where: { $0.departureTime >= now }) ?? results.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(nil) {
                proxy.scrollTo(target.id, anchor: .center)
            }
        }
    }
}
