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

private actor CallLog {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}

private actor RecordingEventCache: EventCaching {
    private let log: CallLog
    private let cache = InMemoryEventCache()

    init(log: CallLog) {
        self.log = log
    }

    func add(_ event: Event) async { await cache.add(event) }
    func pop() async -> [Event] { await cache.pop() }
    func count() async -> Int { await cache.count() }
    func persist() async { await log.record("persist") }
}

/// Stands in for a transmitter whose stop may put an in-flight batch back into the cache.
private actor RecordingEventTransmitter: EventTransmitting {
    private let log: CallLog
    private let cache: any EventCaching
    private let batchReturnedOnStop: [Event]

    init(log: CallLog, cache: any EventCaching, batchReturnedOnStop: [Event]) {
        self.log = log
        self.cache = cache
        self.batchReturnedOnStop = batchReturnedOnStop
    }

    func transmit(_ events: [Event]) async -> [Event] { [] }
    func flush() async {}
    func start() async {}

    func stop() async {
        await log.record("stop")
        await cache.add(batchReturnedOnStop)
    }
}

@Suite
struct TelemetryEngineTests {
    @Test(arguments: [(0, ["persist", "stop"]), (1, ["persist", "stop", "persist"])])
    func terminationSavesBeforeStoppingAndAgainOnlyIfBatchCameBack(returnedEvents: Int, expectedCalls: [String]) async throws {
        let log = CallLog()
        let cache = RecordingEventCache(log: log)
        let client = await TelemetryEngine.create(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            processors: [],
            cache: cache,
            transmitter: RecordingEventTransmitter(
                log: log,
                cache: cache,
                batchReturnedOnStop: (0..<returnedEvents).map { _ in createTestEvent() }
            ),
            storage: InMemoryProcessorStorage()
        )

        await client.handleTermination()

        #expect(await log.calls == expectedCalls)

        await client.shutdown()
    }

    @Test
    func terminationBacksUpBatchThatWasInFlight() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-termination-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = DefaultEventCache(fileURL: fileURL)
        let stub = HangingHTTPClient()
        await cache.add(createTestEvent())

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: DefaultEventTransmitter(configuration: config, cache: cache, logger: DefaultLogger(), httpClient: stub),
            storage: InMemoryProcessorStorage()
        )
        await stub.waitForRequest()

        await client.handleTermination()

        // A new instance stands in for the next launch.
        let nextLaunchCache = DefaultEventCache(fileURL: fileURL)
        await nextLaunchCache.restore()
        #expect(await nextLaunchCache.count() == 1)

        await client.shutdown()
    }

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
