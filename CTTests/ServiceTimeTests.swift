import Testing
@testable import CT

struct ServiceTimeTests {
    @Test func passesOnlyAfterFiveMinuteGracePeriod() {
        let arrival = ServiceTime(secondsSinceMidnight: 11 * 3_600 + 46 * 60)
        #expect(!arrival.isAtLeastFiveMinutesPast(ServiceTime(secondsSinceMidnight: 11 * 3_600 + 50 * 60 + 59)))
        #expect(arrival.isAtLeastFiveMinutesPast(ServiceTime(secondsSinceMidnight: 11 * 3_600 + 51 * 60)))
    }
}
