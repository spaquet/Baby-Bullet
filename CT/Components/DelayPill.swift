//
//  DelayPill.swift
//  CT
//

import SwiftUI

/// Live on-time/delay indicator, or an "unavailable" state when 511 has no
/// current data for this trip/stop (see RealtimeService).
struct DelayPill: View {
    enum State {
        case loading
        case unavailable
        case status(TrainRealtimeStatus)
    }

    let state: State

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().controlSize(.mini)
            case .unavailable:
                label("Live data unavailable", color: Color(.tertiaryLabel), background: Color(.tertiarySystemFill))
            case .status(let status):
                if let minutes = status.delayMinutes {
                    if minutes > 1 {
                        label("Delayed \(minutes) min", color: Color("Warning"), background: Color("WarningBackground"))
                    } else if minutes < -1 {
                        label("Early \(-minutes) min", color: .secondary, background: Color(.secondarySystemFill))
                    } else {
                        label("On time", color: .green, background: Color.green.opacity(0.15))
                    }
                } else {
                    label("Live", color: .secondary, background: Color(.secondarySystemFill))
                }
            }
        }
    }

    private func label(_ text: String, color: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }
}
