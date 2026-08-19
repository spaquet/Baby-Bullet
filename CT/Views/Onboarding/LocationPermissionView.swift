//
//  LocationPermissionView.swift
//  CT
//

import SwiftUI

struct LocationPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "location.circle")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)
                }
                Text("Find your nearest station")
                    .font(.system(size: 26, weight: .bold))
                Text("Baby Bullet uses your location to show departures from the Caltrain station closest to you. Your location is never shared or stored.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
            Spacer()
            VStack(spacing: 10) {
                Button(action: onAllow) {
                    Text("Allow Location Access")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))

                Button(action: onSkip) {
                    Text("Not Now")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    LocationPermissionView(onAllow: {}, onSkip: {})
}
