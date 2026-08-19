//
//  DepartureRow.swift
//  CT
//

import SwiftUI

struct DepartureRow: View {
    let trainNumber: String
    let trainType: TrainType
    let time: ServiceTime
    let destination: String
    /// Riding time from this departure to `destination` (the trip's
    /// terminus, unless the caller resolved a user-chosen destination).
    let rideDurationMinutes: Int
    var isPast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            TrainBadge(trainNumber: trainNumber, trainType: trainType)
            Text(destinationLine)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(ServiceTime.minutesLabel(forMinutes: rideDurationMinutes))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .opacity(isPast ? 0.5 : 1)
        .background(isPast ? Color(.tertiarySystemGroupedBackground) : Color.clear)
    }

    private var destinationLine: AttributedString {
        var result = AttributedString(time.displayString)
        result.foregroundColor = .primary
        var arrow = AttributedString(" → \(destination)")
        arrow.foregroundColor = Color(.tertiaryLabel)
        result.append(arrow)
        return result
    }
}
