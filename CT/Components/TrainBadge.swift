//
//  TrainBadge.swift
//  CT
//

import SwiftUI

struct TrainBadge: View {
    let trainNumber: String
    let trainType: TrainType

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(trainNumber)
                .font(.system(size: 15, weight: .bold))
            Text(trainType.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(trainType.badgeColor)
        .frame(width: 56, alignment: .leading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        TrainBadge(trainNumber: "#146", trainType: .local)
        TrainBadge(trainNumber: "#422", trainType: .limited)
        TrainBadge(trainNumber: "#520", trainType: .express)
    }
    .padding()
}
