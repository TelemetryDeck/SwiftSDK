import Foundation
import Testing

@testable import TelemetryDeck

private actor NoOpEventTransmitter: EventTransmitting {
    private let cache: (any EventCaching)?

    init(cache: (any EventCaching)? = nil) {
        self.cache = cache
    }

    func transmit(_ events: [Event]) async -> [Event] {
        []
    }

    func flush() async {
        guard let cache else { return }
        let events = await cache.pop()
        _ = await transmit(events)
    }

    func start() async {}
    func stop() async {}
}

@Suite
struct TelemetryEngineTests {
    @Test
    func processorOfTypeReturnsCorrectProcessor() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitter = NoOpEventTransmitter(cache: cache)

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [TestModeProcessor(), SessionTrackingProcessor()],
            cache: cache,
            transmitter: transmitter,
            storage: InMemoryProcessorStorage()
        )

        let testModeProcessor = await client.processor(ofType: TestModeProcessor.self)
        #expect(testModeProcessor != nil)

        await client.shutdown()
    }

    @Test
    func processorConformingToReturnsCorrectProcessor() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitter = NoOpEventTransmitter(cache: cache)

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [SessionTrackingProcessor(), TestModeProcessor()],
            cache: cache,
            transmitter: transmitter,
            storage: InMemoryProcessorStorage()
        )

        let sessionManager = await client.processor(conformingTo: SessionManaging.self)
        #expect(sessionManager != nil)

        let testModeProvider = await client.processor(conformingTo: TestModeProviding.self)
        #expect(testModeProvider != nil)

        await client.shutdown()
    }

    @Test
    func processorOfTypeReturnsNilForMissing() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitter = NoOpEventTransmitter(cache: cache)

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [SessionTrackingProcessor()],
            cache: cache,
            transmitter: transmitter,
            storage: InMemoryProcessorStorage()
        )

        let testModeProcessor = await client.processor(ofType: TestModeProcessor.self)
        #expect(testModeProcessor == nil)

        await client.shutdown()
    }

    @Test
    func shutdownDoesNotPreventSubsequentSends() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitter = NoOpEventTransmitter(cache: cache)

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: transmitter,
            storage: InMemoryProcessorStorage()
        )

        await client.shutdown()
        await client.send(EventInput("After.shutdown"))

        let count = await cache.count()
        #expect(count == 1)
    }

    @Test
    func flushEmptiesCacheAfterSend() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitter = NoOpEventTransmitter(cache: cache)

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: transmitter,
            storage: InMemoryProcessorStorage()
        )

        await client.send(EventInput("Test.signal"))

        let countBeforeFlush = await cache.count()
        #expect(countBeforeFlush == 1)

        await client.flush()

        let countAfterFlush = await cache.count()
        #expect(countAfterFlush == 0)

        await client.shutdown()
    }
}
