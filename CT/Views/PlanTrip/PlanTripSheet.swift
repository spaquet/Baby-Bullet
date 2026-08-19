//
//  PlanTripSheet.swift
//  CT
//

import SwiftUI

private enum PickerTarget: Identifiable, Equatable {
    case origin
    case destination
    var id: Self { self }
}

struct PlanTripSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var originID: String?
    @State private var destinationID: String?
    @State private var dayType: DayType = .weekday
    @State private var holidayServiceIDs: Set<String> = []
    @State private var showHolidayTab = false
    @State private var searched = false
    @State private var results: [TripResult] = []
    @State private var pickerTarget: PickerTarget?
    @State private var openResult: TripResult?

    private var originStation: Station? { appModel.stations.first { $0.id == originID } }
    private var destinationStation: Station? { appModel.stations.first { $0.id == destinationID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    odCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    dayTypePicker
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    Button {
                        Task { await search() }
                    } label: {
                        Text("Find Trains")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .disabled(originID == nil || destinationID == nil || originID == destinationID)

                    if searched {
                        resultsList
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan a Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $pickerTarget) { target in
                StationPickerSheet(
                    title: target == .origin ? "Departing From" : "Arriving At",
                    stations: appModel.stations,
                    selectedID: target == .origin ? originID : destinationID
                ) { station in
                    if target == .origin { originID = station.id } else { destinationID = station.id }
                }
            }
            .sheet(item: $openResult) { result in
                StopsSheet(tripID: result.tripID, trainNumber: result.trainNumber, trainType: result.trainType, preloadedStops: result.stops)
            }
            .task { await prepareDefaults() }
        }
    }

    private var odCard: some View {
        VStack(spacing: 2) {
            Button { pickerTarget = .origin } label: {
                stationRow(label: "FROM", name: originStation?.name ?? "Choose a station", dotColor: Color.accentColor)
            }
            .buttonStyle(.plain)

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

            Button { pickerTarget = .destination } label: {
                stationRow(label: "TO", name: destinationStation?.name ?? "Choose a station", dotColor: Color("BadgeExpress"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func stationRow(label: String, name: String, dotColor: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(dotColor.opacity(0.15)).frame(width: 22, height: 22)
                .overlay(Circle().fill(dotColor).frame(width: 7, height: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                Text(name).font(.system(size: 17, weight: .medium)).foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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

    private var resultsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(originStation?.name ?? "") → \(destinationStation?.name ?? "")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 8)

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
                        }
                        .buttonStyle(.plain)
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

    private func prepareDefaults() async {
        if originID == nil { originID = appModel.homeStationID }
        if destinationID == nil {
            destinationID = appModel.stations.first { $0.id != originID }?.id
        }
        if let active = try? await appModel.db.activeServices(on: Date()) {
            holidayServiceIDs = active.holidayOnlyServiceIDs
            showHolidayTab = active.isHoliday
        }
    }

    private func search() async {
        guard let originID, let destinationID else { return }
        let serviceIDs: Set<String>
        switch dayType {
        case .weekday: serviceIDs = (try? await appModel.db.weekdayServiceIDs()) ?? []
        case .weekend: serviceIDs = (try? await appModel.db.weekendServiceIDs()) ?? []
        case .holiday: serviceIDs = holidayServiceIDs
        }
        results = (try? await appModel.db.tripResults(originStationID: originID, destinationStationID: destinationID, serviceIDs: serviceIDs)) ?? []
        searched = true
    }
}
