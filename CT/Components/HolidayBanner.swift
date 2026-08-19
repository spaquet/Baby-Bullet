//
//  HolidayBanner.swift
//  CT
//

import SwiftUI

struct HolidayBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(Color("Warning"))
            Text("Holiday schedule in effect today")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("WarningBackground"), in: RoundedRectangle(cornerRadius: 16))
    }
}
