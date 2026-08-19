//
//  BabyBulletWidget.swift
//  BabyBulletWidget
//

import SwiftUI
import WidgetKit
import AppIntents

nonisolated private enum WidgetConstants {
    static let appGroupID = "group.com.stephanepaquet.CT"
    static let snapshotKey = "widgetSnapshot"
    static let returnTripKey = "widgetShowsReturnTrip"
}

private struct Departure: Codable {
    let trainNumber: String
    let destination: String
    let secondsSinceMidnight: Int
}

private struct Snapshot: Codable {
    let stationID: String
    let stationName: String
    let serviceDate: String
    let departures: [Departure]
    let returnStationName: String?
    let returnDepartures: [Departure]
}

private struct Entry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: Snapshot(stationID: "palo_alto", stationName: "Palo Alto", serviceDate: "", departures: [
            Departure(trainNumber: "123", destination: "San Francisco", secondsSinceMidnight: 9 * 3_600 + 12 * 60),
            Departure(trainNumber: "456", destination: "San Francisco", secondsSinceMidnight: 9 * 3_600 + 42 * 60)
        ], returnStationName: "Palo Alto", returnDepartures: []))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let entry = Entry(date: now, snapshot: loadSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> Snapshot? {
        guard let data = UserDefaults(suiteName: WidgetConstants.appGroupID)?.data(forKey: WidgetConstants.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

struct ToggleWidgetDirectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Reverse Commute"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: WidgetConstants.appGroupID)
        defaults?.set(!(defaults?.bool(forKey: WidgetConstants.returnTripKey) ?? false), forKey: WidgetConstants.returnTripKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "BabyBulletWidget")
        return .result()
    }
}

struct BabyBulletWidget: Widget {
    let kind = "BabyBulletWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Departures")
        .description("The next two departures from your Home Station.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct WidgetView: View {
    let entry: Entry

    private var departures: [Departure] {
        guard let snapshot = entry.snapshot else { return [] }
        let components = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        let now = (components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60
        return Array(activeDepartures(for: snapshot).filter { $0.secondsSinceMidnight >= now }.prefix(2))
    }

    private func activeDepartures(for snapshot: Snapshot) -> [Departure] {
        guard UserDefaults(suiteName: WidgetConstants.appGroupID)?.bool(forKey: WidgetConstants.returnTripKey) == true,
              !snapshot.returnDepartures.isEmpty
        else { return snapshot.departures }
        return snapshot.returnDepartures
    }

    private var isReturnTrip: Bool {
        guard let snapshot = entry.snapshot else { return false }
        return UserDefaults(suiteName: WidgetConstants.appGroupID)?.bool(forKey: WidgetConstants.returnTripKey) == true && !snapshot.returnDepartures.isEmpty
    }

    var body: some View {
        if let snapshot = entry.snapshot, !departures.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(isReturnTrip ? (snapshot.returnStationName ?? snapshot.stationName) : snapshot.stationName)
                    .font(.headline)
                    .lineLimit(1)
                if snapshot.returnStationName != nil {
                    HStack {
                        Text(isReturnTrip ? "To Home" : "To Work")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(intent: ToggleWidgetDirectionIntent()) {
                            Image(systemName: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(departures, id: \.trainNumber) { departure in
                    HStack {
                        Text(time(for: departure))
                            .font(.title3.bold())
                        Text(departure.destination)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .widgetURL(URL(string: "babybullet://home"))
        } else {
            ContentUnavailableView("No Upcoming Trains", systemImage: "train.side.front.car", description: Text("Open Baby Bullet to refresh departures."))
                .widgetURL(URL(string: "babybullet://home"))
        }
    }

    private func time(for departure: Departure) -> String {
        String(format: "%d:%02d", (departure.secondsSinceMidnight / 3_600) % 24, (departure.secondsSinceMidnight % 3_600) / 60)
    }
}
