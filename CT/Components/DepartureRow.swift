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
    let minutesUntil: Int

    var body: some View {
        HStack(spacing: 12) {
            TrainBadge(trainNumber: trainNumber, trainType: trainType)
            Text(destinationLine)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(ServiceTime.minutesLabel(forMinutes: minutesUntil))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
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
