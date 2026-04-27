import Foundation
import Testing

@testable import TelemetryDeck

struct DurationTrackerTests {
    @Test
    func startAndStopReturnsElapsedDuration() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        clock.advance(by: 0.1)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(abs(result!.durationInSeconds - 0.1) < 0.0001)
    }

    @Test
    func stopNonexistentDurationReturnsNil() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        let result = await tracker.stopDuration("nonexistent.duration")

        #expect(result == nil)
    }

    @Test
    func cancelDurationPreventsStop() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        clock.advance(by: 0.1)

        await tracker.cancelDuration("test.duration")

        let result = await tracker.stopDuration("test.duration")

        #expect(result == nil)
    }

    @Test
    func startParametersAreReturnedOnStop() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        var params = EventParameters()
        params["key1"] = "value1"
        params["key2"] = "value2"

        await tracker.startDuration(
            "test.duration",
            parameters: params,
            includeBackgroundTime: true
        )

        clock.advance(by: 0.1)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(result!.startParameters.payloadDictionary["key1"] == .string("value1"))
        #expect(result!.startParameters.payloadDictionary["key2"] == .string("value2"))
    }

    @Test
    func backgroundTimeExcludedWhenFlagIsFalse() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: false
        )

        clock.advance(by: 0.05)

        await tracker.handleBackground()

        clock.advance(by: 0.10)

        await tracker.handleForeground()

        clock.advance(by: 0.05)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(abs(result!.durationInSeconds - 0.10) < 0.0001)
    }

    @Test
    func backgroundTimeIncludedWhenFlagIsTrue() async throws {
        let clock = MutableClock()
        let tracker = DurationTracker(dateProvider: clock.dateProvider)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        clock.advance(by: 0.05)

        await tracker.handleBackground()

        clock.advance(by: 0.10)

        await tracker.handleForeground()

        clock.advance(by: 0.05)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(abs(result!.durationInSeconds - 0.20) < 0.0001)
    }

    @Test
    func persistAndRestoreRoundtrip() async throws {
        let clock = MutableClock()
        let storage = InMemoryProcessorStorage()

        let tracker1 = DurationTracker(dateProvider: clock.dateProvider)
        await tracker1.start(storage: storage)

        var params = EventParameters()
        params["key"] = "value"

        await tracker1.startDuration(
            "test.duration",
            parameters: params,
            includeBackgroundTime: false
        )

        clock.advance(by: 0.05)

        await tracker1.stop()

        let tracker2 = DurationTracker(dateProvider: clock.dateProvider)
        await tracker2.start(storage: storage)

        clock.advance(by: 0.05)

        let result = await tracker2.stopDuration("test.duration")

        #expect(result != nil)
        #expect(result!.durationInSeconds > 0.05)
        #expect(result!.startParameters.payloadDictionary["key"] == .string("value"))

        await tracker2.stop()
    }
}
