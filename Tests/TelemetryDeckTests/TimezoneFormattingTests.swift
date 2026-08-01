import Foundation
import Testing

@testable import TelemetryDeck

struct TimezoneFormattingTests {
    @Test
    func utcPlusZero() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC+0")
    }

    @Test
    func utcPlusFiveThirty() {
        let timeZone = TimeZone(secondsFromGMT: 19800)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC+5:30")
    }

    @Test
    func utcMinusFive() {
        let timeZone = TimeZone(secondsFromGMT: -18000)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC-5")
    }

    @Test
    func utcMinusNineThirty() {
        let timeZone = TimeZone(secondsFromGMT: -34200)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC-9:30")
    }

    @Test
    func utcPlusTwelve() {
        let timeZone = TimeZone(secondsFromGMT: 43200)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC+12")
    }

    @Test
    func utcPlusFiveFortyFive() {
        let timeZone = TimeZone(secondsFromGMT: 20700)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC+5:45")
    }

    @Test
    func utcMinusThreeThirty() {
        let timeZone = TimeZone(secondsFromGMT: -12600)!
        let result = TimezoneFormatting.utcOffsetString(from: timeZone)
        #expect(result == "UTC-3:30")
    }
}
