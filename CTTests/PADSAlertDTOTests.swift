//
//  PADSAlertDTOTests.swift
//  CTTests
//
//  Fixture below is trimmed from a live response from
//  caltrain.com/gtfs/api/v1/servicealerts/Caltrain — see PADSAlertDTO.swift
//  for why this second, undocumented source exists alongside 511's feed.
//

import Testing
@testable import CT
import Foundation

struct PADSAlertDTOTests {

    @Test func decodesPADSAlerts() throws {
        let data = padsAlertsFixture.data(using: .utf8)!
        let entities = try JSONDecoder().decode([PADSAlertEntity].self, from: data)

        #expect(entities.count == 2)
        #expect(entities[0].Id == 6526)
        #expect(entities[0].Alert.HeaderText?.text == nil) // PADS leaves the header blank
        #expect(entities[0].Alert.DescriptionText?.text == "Tamien-Diridon service suspended on select weekends through Sept. 20. Plan ahead: caltrain.com/status . ")
    }
}

private let padsAlertsFixture = """
[
  {
    "Id": 6526,
    "Alert": {
      "ActivePeriod": [{"Start": 1786964400}],
      "InformedEntity": [{"AgencyId": "CT"}, {"AgencyId": "CT", "StopId": "sj_diridon"}, {"AgencyId": "CT", "StopId": "tamien"}],
      "HeaderText": {"Translation": [{"Text": "", "Language": "en"}]},
      "DescriptionText": {"Translation": [{"Text": "Tamien-Diridon service suspended on select weekends through Sept. 20. Plan ahead: caltrain.com/status . ", "Language": "en"}]}
    },
    "Source": "PADS"
  },
  {
    "Id": 1175,
    "Alert": {
      "ActivePeriod": [{"Start": 1786878000}],
      "InformedEntity": [{"AgencyId": "CT"}],
      "HeaderText": {"Translation": [{"Text": "", "Language": "en"}]},
      "DescriptionText": {"Translation": [{"Text": "Please arrive early to purchase your fare or tap your card, and be ready to board when your train arrives.. ", "Language": "en"}]}
    },
    "Source": "PADS"
  }
]
"""
