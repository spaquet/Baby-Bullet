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

    @Test func decodesActiveServiceAlert() throws {
        let data = activeServiceAlertFixture.data(using: .utf8)!
        let response = try JSONDecoder().decode(ServiceAlertsResponse.self, from: data)

        let entity = try #require(response.Entities?.first)
        #expect(entity.Id == "CT_20807ef4-495f-49a9-9b5b-1867ab4767fb")
        let alert = try #require(entity.Alert)
        #expect(alert.HeaderText?.text == "Platform change: Train 519 northbound will depart from platform 2 at San Jose Diridon.")
        #expect(alert.DescriptionText?.text == nil) // real payload has an empty English translation
        #expect(alert.effect == 6)
        #expect(alert.cause == 2)
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

private let activeServiceAlertFixture = """
{"Header":{"GtfsRealtimeVersion":"1.0","incrementality":0,"Timestamp":1787181728},"Entities":[{"Id":"CT_20807ef4-495f-49a9-9b5b-1867ab4767fb","TripUpdate":null,"Vehicle":null,"Alert":{"ActivePeriods":[{"Start":1787179809,"End":1787181911}],"InformedEntities":[{"AgencyId":"CT","Trip":{"TripId":"519","schedule_relationship":0},"StopId":"70261"}],"cause":2,"effect":6,"Url":null,"HeaderText":{"Translations":[{"Text":"Platform change: Train 519 northbound will depart from platform 2 at San Jose Diridon.","Language":"en"},{"Text":"Cambio de and\\u00e9n: El tren 519 con direcci\\u00f3n norte saldr\\u00e1 del plataforma del tren 2 en San Jose Diridon.","Language":"es"}]},"DescriptionText":{"Translations":[{"Text":"","Language":"en"}]},"TtsHeaderText":null,"TtsDescriptionText":null,"severity_level":3}}]}
"""
