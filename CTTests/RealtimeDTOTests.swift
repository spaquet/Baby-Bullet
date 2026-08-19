//
//  RealtimeDTOTests.swift
//  CTTests
//
//  Fixtures below are trimmed real payloads captured live from
//  api.511.org/transit/{StopMonitoring,VehicleMonitoring,servicealerts}
//  (agency=CT, format=json) while planning this feature — locks in the BOM
//  handling and the mismatched Siri-envelope shape between the two SIRI
//  endpoints.
//

import Testing
@testable import CT
import Foundation

struct RealtimeDTOTests {

    @Test func decodesStopMonitoringWithBOM() throws {
        var data = stopMonitoringFixture.data(using: .utf8)!
        data = Data([0xEF, 0xBB, 0xBF]) + data // real responses arrive with a BOM

        var trimmed = data
        if trimmed.prefix(3).elementsEqual([0xEF, 0xBB, 0xBF]) {
            trimmed = trimmed.dropFirst(3)
        }
        let response = try JSONDecoder().decode(StopMonitoringResponse.self, from: trimmed)

        let visit = try #require(response.ServiceDelivery.StopMonitoringDelivery.MonitoredStopVisit?.first)
        #expect(visit.MonitoredVehicleJourney.FramedVehicleJourneyRef?.DatedVehicleJourneyRef == "127")
        #expect(visit.MonitoredVehicleJourney.MonitoredCall?.StopPointRef == "70021")
        #expect(visit.MonitoredVehicleJourney.VehicleLocation?.Latitude == "37.7072983")
    }

    @Test func decodesVehicleMonitoringSiriEnvelope() throws {
        let data = vehicleMonitoringFixture.data(using: .utf8)!
        let response = try JSONDecoder().decode(VehicleMonitoringResponse.self, from: data)

        let activity = try #require(response.Siri.ServiceDelivery.VehicleMonitoringDelivery.VehicleActivity?.first)
        #expect(activity.MonitoredVehicleJourney.FramedVehicleJourneyRef?.DatedVehicleJourneyRef == "126")
        #expect(activity.MonitoredVehicleJourney.MonitoredCall?.StopPointRef == "70242")
    }

    @Test func decodesEmptyServiceAlerts() throws {
        let data = serviceAlertsFixture.data(using: .utf8)!
        let response = try JSONDecoder().decode(ServiceAlertsResponse.self, from: data)

        #expect(response.Entities?.isEmpty == true)
    }
}

private let stopMonitoringFixture = """
{"ServiceDelivery":{"ResponseTimestamp":"2026-08-19T19:35:42Z","ProducerRef":"CT","Status":true,"StopMonitoringDelivery":{"version":"1.4","ResponseTimestamp":"2026-08-19T19:35:42Z","Status":true,"MonitoredStopVisit":[{"RecordedAtTime":"2026-08-19T19:35:29Z","MonitoringRef":"70021","MonitoredVehicleJourney":{"LineRef":"Local Weekday","DirectionRef":"N","FramedVehicleJourneyRef":{"DataFrameRef":"2026-08-19","DatedVehicleJourneyRef":"127"},"PublishedLineName":"","OperatorRef":"CT","OriginRef":"70261","OriginName":"San Jose Diridon Caltrain Station Northbound","DestinationRef":"70011","DestinationName":"San Francisco Caltrain Station Northbound","Monitored":true,"InCongestion":null,"VehicleLocation":{"Longitude":"-122.401802","Latitude":"37.7072983"},"Bearing":null,"Occupancy":null,"VehicleRef":"127","MonitoredCall":{"StopPointRef":"70021","StopPointName":"22nd Street Caltrain Station Northbound","VehicleLocationAtStop":"","VehicleAtStop":"","DestinationDisplay":"San Francisco","AimedArrivalTime":"2026-08-19T19:40:00Z","ExpectedArrivalTime":"2026-08-19T19:39:06Z","AimedDepartureTime":"2026-08-19T19:40:00Z","ExpectedDepartureTime":"2026-08-19T19:40:06Z","Distances":""}}}]}}}
"""

private let vehicleMonitoringFixture = """
{"Siri":{"ServiceDelivery":{"ResponseTimestamp":"2026-08-19T19:35:52Z","ProducerRef":"CT","Status":true,"VehicleMonitoringDelivery":{"version":"1.4","ResponseTimestamp":"2026-08-19T19:35:52Z","VehicleActivity":[{"RecordedAtTime":"2026-08-19T19:35:43Z","ValidUntilTime":"","MonitoredVehicleJourney":{"LineRef":"Local Weekday","DirectionRef":"S","FramedVehicleJourneyRef":{"DataFrameRef":"2026-08-19","DatedVehicleJourneyRef":"126"},"PublishedLineName":"","OperatorRef":"CT","OriginRef":"70012","OriginName":"San Francisco Caltrain Station Southbound","DestinationRef":"70262","DestinationName":"San Jose Diridon Caltrain Station Southbound","Monitored":true,"InCongestion":null,"VehicleLocation":{"Longitude":"-121.938492","Latitude":"37.3543015"},"Bearing":null,"Occupancy":null,"VehicleRef":"126","MonitoredCall":{"StopPointRef":"70242","StopPointName":"Santa Clara Caltrain Station Southbound","DestinationDisplay":"San Jose Diridon","VehicleLocationAtStop":"","VehicleAtStop":"","AimedArrivalTime":"2026-08-19T19:36:00Z","ExpectedArrivalTime":"2026-08-19T19:35:36Z","AimedDepartureTime":"2026-08-19T19:36:00Z","ExpectedDepartureTime":"2026-08-19T19:36:36Z"},"OnwardCalls":{"OnwardCall":[]}}}]}}}}
"""

private let serviceAlertsFixture = """
{"Header":{"GtfsRealtimeVersion":"1.0","incrementality":0,"Timestamp":1787168141},"Entities":[]}
"""
