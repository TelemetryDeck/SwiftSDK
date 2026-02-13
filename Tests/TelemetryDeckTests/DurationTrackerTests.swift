import Foundation
import Testing

@testable import TelemetryDeck

struct DurationTrackerTests {
    @Test
    func startAndStopReturnsElapsedDuration() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(result!.durationInSeconds > 0)

        await tracker.stop()
    }

    @Test
    func stopNonexistentDurationReturnsNil() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        let result = await tracker.stopDuration("nonexistent.duration")

        #expect(result == nil)

        await tracker.stop()
    }

    @Test
    func cancelDurationPreventsStop() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        await tracker.cancelDuration("test.duration")

        let result = await tracker.stopDuration("test.duration")

        #expect(result == nil)

        await tracker.stop()
    }

    @Test
    func startParametersAreReturnedOnStop() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        var params = EventParameters()
        params["key1"] = "value1"
        params["key2"] = "value2"

        await tracker.startDuration(
            "test.duration",
            parameters: params,
            includeBackgroundTime: true
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)
        #expect(result!.startParameters.stringDictionary["key1"] == "value1")
        #expect(result!.startParameters.stringDictionary["key2"] == "value2")

        await tracker.stop()
    }

    @Test
    func backgroundTimeExcludedWhenFlagIsFalse() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        let startTime = Date()

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        await tracker.handleBackground()

        try await Task.sleep(nanoseconds: 100_000_000)

        await tracker.handleForeground()

        try await Task.sleep(nanoseconds: 50_000_000)

        let result = await tracker.stopDuration("test.duration")
        let wallClockElapsed = Date().timeIntervalSince(startTime)

        #expect(result != nil)
        #expect(result!.durationInSeconds < wallClockElapsed)
        #expect(result!.durationInSeconds < 0.25)

        await tracker.stop()
    }

    @Test
    func backgroundTimeIncludedWhenFlagIsTrue() async throws {
        let tracker = DurationTracker()
        let storage = InMemoryProcessorStorage()
        await tracker.start(storage: storage)

        await tracker.startDuration(
            "test.duration",
            parameters: EventParameters(),
            includeBackgroundTime: true
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        await tracker.handleBackground()

        try await Task.sleep(nanoseconds: 100_000_000)

        await tracker.handleForeground()

        try await Task.sleep(nanoseconds: 50_000_000)

        let result = await tracker.stopDuration("test.duration")

        #expect(result != nil)

        await tracker.stop()
    }

    @Test
    func persistAndRestoreRoundtrip() async throws {
        let storage = InMemoryProcessorStorage()

        let tracker1 = DurationTracker()
        await tracker1.start(storage: storage)

        var params = EventParameters()
        params["key"] = "value"

        await tracker1.startDuration(
            "test.duration",
            parameters: params,
            includeBackgroundTime: false
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        await tracker1.stop()

        let tracker2 = DurationTracker()
        await tracker2.start(storage: storage)

        try await Task.sleep(nanoseconds: 50_000_000)

        let result = await tracker2.stopDuration("test.duration")

        #expect(result != nil)
        #expect(result!.durationInSeconds > 0.05)
        #expect(result!.startParameters.stringDictionary["key"] == "value")

        await tracker2.stop()
    }
}
