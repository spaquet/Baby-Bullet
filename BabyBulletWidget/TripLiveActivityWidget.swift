//
//  TripLiveActivityWidget.swift
//  BabyBulletWidget
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            lockScreenView(context: context)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.trainNumber).font(.headline)
                        Text(context.attributes.destName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.statusLabel)
                        .font(.caption.bold())
                        .foregroundStyle(color(for: context.state.delayMinutes))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let arrival = context.state.expectedArrival {
                        Text("Arrives \(arrival, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "train.side.front.car")
            } compactTrailing: {
                Text(compactStatus(context.state))
                    .font(.caption2.bold())
                    .foregroundStyle(color(for: context.state.delayMinutes))
            } minimal: {
                Image(systemName: "train.side.front.car")
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<TripActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.originName) → \(context.attributes.destName)")
                    .font(.subheadline.bold())
                Text("Train \(context.attributes.trainNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.statusLabel)
                    .font(.subheadline.bold())
                    .foregroundStyle(color(for: context.state.delayMinutes))
                if let arrival = context.state.expectedArrival {
                    Text("Arrives \(arrival, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func compactStatus(_ state: TripActivityAttributes.ContentState) -> String {
        guard let delay = state.delayMinutes, delay > 1 else { return "On time" }
        return "+\(delay)m"
    }

    private func color(for delayMinutes: Int?) -> Color {
        guard let delayMinutes, delayMinutes > 1 else { return .green }
        return .orange
    }
}
