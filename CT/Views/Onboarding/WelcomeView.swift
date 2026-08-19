//
//  WelcomeView.swift
//  CT
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    private let bullets = [
        "Live schedules for every station",
        "Trip planning between any two stops",
        "Service alerts, once our status feed ships",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.accentColor)
                        .frame(width: 96, height: 96)
                        .shadow(color: .accentColor.opacity(0.35), radius: 20, y: 12)
                    Image(systemName: "tram.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
                Text("Baby Bullet")
                    .font(.system(size: 30, weight: .bold))
                Text("Caltrain timetables, station info, and trip planning — simplified.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(spacing: 10) {
                            Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                            Text(bullet)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
            Spacer()
            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
