import Testing
@testable import CT
import Foundation

struct DayTypeTests {
    @Test func defaultsToTheCaliforniaWeekendSchedule() {
        let saturday = Date(timeIntervalSince1970: 1_785_009_600) // 2026-07-25 13:00 PDT
        let monday = Date(timeIntervalSince1970: 1_785_182_400) // 2026-07-27 13:00 PDT

        #expect(DayType.defaultRegularSchedule(for: saturday) == .weekend)
        #expect(DayType.defaultRegularSchedule(for: monday) == .weekday)
    }
}
