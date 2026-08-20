//
//  StationDetailView.swift
//  CT
//

import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: Station
    let isRideDestination: Bool

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var platforms: [Platform] = []

    var body: some View {
        NavigationStack {
            List {
                Map(initialPosition: .region(mapRegion)) {
                    Marker(station.name, coordinate: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude))
                }
                .frame(height: 180)
                .listRowInsets(EdgeInsets())

                Section("Accessibility") {
                    Label(accessibilityMessage, systemImage: "figure.roll")
                        .foregroundStyle(.secondary)
                }

                Section("Directions") {
                    Link(destination: directionsURL) {
                        Label("Open in Maps", systemImage: "map")
                    }
                    Link(destination: uberURL) {
                        Label(isRideDestination ? "Ride to This Station with Uber" : "Ride from This Station with Uber", systemImage: "car")
                    }
                }
            }
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.fraction(0.78), .large])
    }

    private var directionsURL: URL {
        URL(string: "https://maps.apple.com/?daddr=\(station.latitude),\(station.longitude)&dirflg=r")!
    }

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    }

    private var uberURL: URL {
        let locationJSON = "{\"latitude\":\(station.latitude),\"longitude\":\(station.longitude),\"addressLine1\":\"\(station.name)\"}"
        var components = URLComponents(string: "https://m.uber.com/looking")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Secrets.uberClientID),
            URLQueryItem(name: isRideDestination ? "drop[0]" : "pickup", value: locationJSON),
        ]
        return components.url!
    }

    private var accessibilityMessage: String {
        let inaccessible = platforms.filter { $0.accessibility == .unavailable }
        if !inaccessible.isEmpty {
            return "Wheelchair boarding is unavailable at \(inaccessible.map(\.name).joined(separator: ", "))."
        }
        if platforms.contains(where: { $0.accessibility == .unknown }) {
            return "Wheelchair boarding information is unavailable."
        }
        return platforms.isEmpty ? "Wheelchair boarding information is unavailable." : "Wheelchair boarding is available."
    }

    private func load() async {
        platforms = (try? await appModel.db.platforms(stationID: station.id)) ?? []
    }
}
