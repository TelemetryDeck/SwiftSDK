import Foundation
import Testing

@testable import TelemetryDeck

struct IntegrationTests {
    @Test
    func fullEventFlowToCache() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "integration-test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [TestModeProcessor()],
            cache: cache,
            transmitter: spy
        )

        let input = EventInput("Integration.test", parameters: ["key": "value"])
        await client.send(input)

        let count = await cache.count()
        #expect(count == 1)

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "Integration.test")
        #expect(events[0].payload["key"] == "value")

        await client.shutdown()
    }

    @Test
    func analyticsDisabledPreventsEvents() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: spy
        )

        await client.setAnalyticsDisabled(true)
        await client.send(EventInput("Should.not.send"))

        let count = await cache.count()
        #expect(count == 0)

        await client.shutdown()
    }

    @Test
    func previewFilterBlocksEvents() async throws {
        setenv("XCODE_RUNNING_FOR_PREVIEWS", "1", 1)

        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [PreviewFilterProcessor()],
            cache: cache,
            transmitter: spy
        )

        await client.send(EventInput("Should.be.filtered"))

        let count = await cache.count()
        #expect(count == 0)

        setenv("XCODE_RUNNING_FOR_PREVIEWS", "0", 1)
        await client.shutdown()
    }

    @Test
    func clientShutdownPersistsCache() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: spy
        )

        await client.send(EventInput("Before.shutdown"))

        let countBeforeShutdown = await cache.count()
        #expect(countBeforeShutdown == 1)

        await client.shutdown()

        let countAfterShutdown = await cache.count()
        #expect(countAfterShutdown == 1)
    }

    @Test
    func floatValueIsPreserved() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: spy
        )

        let input = EventInput("Test.floatValue", floatValue: 42.5)
        await client.send(input)

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].floatValue == 42.5)

        await client.shutdown()
    }

    @Test
    func customUserIDIsUsedForHashing() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [UserIdentifierProcessor()],
            cache: cache,
            transmitter: spy
        )

        let input = EventInput("Test.customUser", customUserID: "custom@user.com")
        await client.send(input)

        let events = await cache.pop()
        #expect(events.count == 1)

        let expectedHash = CryptoHashing.sha256(string: "custom@user.com", salt: "")
        #expect(events[0].clientUser == expectedHash)

        await client.shutdown()
    }

    @Test
    func newInstallDetectedIncludesFirstSessionDate() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: spy
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let firstSessionDate = formatter.string(from: Date())

        let input = EventInput(
            DefaultEvents.Acquisition.newInstallDetected.rawValue,
            parameters: [DefaultParams.Acquisition.firstSessionDate.rawValue: firstSessionDate]
        )
        await client.send(input)

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == DefaultEvents.Acquisition.newInstallDetected.rawValue)

        let dateParam = events[0].payload[DefaultParams.Acquisition.firstSessionDate.rawValue]
        #expect(dateParam != nil)

        guard case .string(let dateStr) = dateParam else {
            Issue.record("firstSessionDate is not a string PayloadValue")
            return
        }
        let parsedDate = formatter.date(from: dateStr)
        #expect(parsedDate != nil)

        await client.shutdown()
    }

    @Test
    func syncSignalFiresEvent() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test-sync", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: spy
        )

        let input = EventInput("Sync.test", parameters: ["key": "value"])
        Task { await client.send(input) }

        try await Task.sleep(nanoseconds: 200_000_000)

        let count = await cache.count()
        #expect(count == 1)

        await client.shutdown()
    }

    @Test
    func testModeIsSetInDebugBuild() async throws {
        let cache = InMemoryEventCache()
        let spy = SpyEventTransmitter()
        let config = TelemetryDeck.Config(appID: "test", namespace: "test")

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [TestModeProcessor()],
            cache: cache,
            transmitter: spy
        )

        await client.send(EventInput("Test.testMode"))

        let events = await cache.pop()
        #expect(events.count == 1)

        #if DEBUG
            #expect(events[0].isTestMode == "true")
        #else
            #expect(events[0].isTestMode == "false")
        #endif

        await client.shutdown()
    }
}
