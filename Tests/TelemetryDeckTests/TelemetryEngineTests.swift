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
    func flushInBackgroundRefreshesSnapshotSoSentEventsAreNotResent() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-background-flush-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cache = DefaultEventCache(fileURL: fileURL)
        let client = await TelemetryEngine.create(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            processors: [],
            cache: cache,
            transmitter: NoOpEventTransmitter(cache: cache),
            storage: InMemoryProcessorStorage()
        )
        await cache.add(makeEvent())

        await client.handleBackground()
        await client.flush()

        // A new instance stands in for the next launch after the process was killed.
        let nextLaunchCache = DefaultEventCache(fileURL: fileURL)
        await nextLaunchCache.restore()
        #expect(await nextLaunchCache.count() == 0)

        await client.shutdown()
    }

    @Test
    func flushInForegroundDoesNotWriteSnapshot() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-foreground-flush-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cache = DefaultEventCache(fileURL: fileURL)
        let client = await TelemetryEngine.create(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            processors: [],
            cache: cache,
            transmitter: NoOpEventTransmitter(),
            storage: InMemoryProcessorStorage()
        )
        await cache.add(makeEvent())

        await client.flush()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))

        await client.shutdown()
    }

    @Test(arguments: [(200, ["Queued"]), (503, ["In.flight", "Queued"])])
    func backgroundSnapshotKeepsTheBatchInFlightOnlyIfItFails(statusCode: Int, snapshot: [String]) async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-background-in-flight-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let (cache, client, engine) = await makeEngineWithRequestInFlight(fileURL: fileURL)
        await cache.add(makeEvent(type: "Queued"))

        let background = Task { await engine.handleBackground() }
        #expect(await eventually { (try? snapshotEventTypes(at: fileURL)) == ["Queued"] })
        client.respond(statusCode: statusCode)
        await background.value

        #expect(client.cancelledRequestCount == 0)
        #expect(try snapshotEventTypes(at: fileURL).sorted() == snapshot)
        #expect(await cache.count() == snapshot.count)

        await engine.shutdown()
    }

    @Test
    func shutdownReturnsOnlyAfterTheBatchInFlightIsBackInCacheAndSnapshot() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-shutdown-in-flight-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let (cache, client, engine) = await makeEngineWithRequestInFlight(fileURL: fileURL)

        let shutdown = Task { await engine.shutdown() }
        client.respond(statusCode: 503)
        await shutdown.value

        #expect(try snapshotEventTypes(at: fileURL) == ["In.flight"])
        #expect(try client.sentEventTypes() == [["In.flight"]])
        #expect(client.cancelledRequestCount == 0)
        #expect(await cache.count() == 1)
    }

    private func makeEngineWithRequestInFlight(fileURL: URL) async -> (DefaultEventCache, ScriptedHTTPClient, TelemetryEngine) {
        let configuration = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = DefaultEventCache(fileURL: fileURL)
        let client = ScriptedHTTPClient()
        let transmitter = DefaultEventTransmitter(
            configuration: configuration,
            cache: cache,
            logger: NoOpLogger(),
            httpClient: client
        )
        await cache.add(makeEvent(type: "In.flight"))
        let engine = await TelemetryEngine.create(
            configuration: configuration,
            processors: [],
            cache: cache,
            transmitter: transmitter,
            logger: NoOpLogger(),
            storage: InMemoryProcessorStorage()
        )
        await client.waitForRequests(1)
        return (cache, client, engine)
    }

    private func snapshotEventTypes(at fileURL: URL) throws -> [String] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.telemetryDecoder.decode([Event].self, from: data).map(\.type)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<15_000 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        return condition()
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
