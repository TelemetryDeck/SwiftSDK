import Foundation
import Testing

@testable import TelemetryDeck

struct ApproachableConcurrencyTests {
    @Test
    func customProcessorCompilesUnderMainActorIsolation() async throws {
        let processor = TestProcessor()
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let finalizer = EventFinalizer(configuration: config)
        let pipeline = ProcessorPipeline(processors: [processor], finalizer: finalizer)

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.type == "Test.signal")
        #expect(signal.payload["customKey"] == "customValue")
    }

    @Test
    func eventParametersDictionaryLiteralWorksUnderMainActorIsolation() {
        let params: EventParameters = [
            "stringParam": "value",
            "intParam": 42,
            "boolParam": true,
        ]

        #expect(params["stringParam"] as? String == "value")
        #expect(params["intParam"] as? Int == 42)
        #expect(params["boolParam"] as? Bool == true)
    }

    @Test
    func telemetryDeckEventCallCompilesUnderMainActorIsolation() async throws {
        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "test-concurrency", namespace: "test")
        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await client.send(EventInput("Test.approachableConcurrency", parameters: ["testKey": "testValue"]))

        let count = await cache.count()
        #expect(count == 1)

        await client.shutdown()
    }

    @Test
    func eventInputCreationWorksUnderMainActorIsolation() {
        let input = EventInput(
            "Test.signal",
            parameters: ["key": "value"],
            floatValue: 1.23,
            customUserID: "user@example.com"
        )

        #expect(input.name == "Test.signal")
        #expect(input.parameters["key"] as? String == "value")
        #expect(input.floatValue == 1.23)
        #expect(input.customUserID == "user@example.com")
    }

    @Test
    func syncEventCompilesUnderMainActorIsolation() {
        let input = EventInput("Test.syncSignal", parameters: ["key": "value"], floatValue: 1.0)
        #expect(input.name == "Test.syncSignal")
        #expect(input.floatValue == 1.0)
    }

    @Test
    func eventContextMutationWorksUnderMainActorIsolation() {
        var context = EventContext()

        context.addParameter("key1", value: "value1")
        context.addParameter("key2", value: 42)

        context.sessionID = UUID()
        context.userIdentifier = "user123"
        context.isTestMode = true

        #expect(context.metadata["key1"] as? String == "value1")
        #expect(context.metadata["key2"] as? Int == 42)
        #expect(context.sessionID != nil)
        #expect(context.userIdentifier == "user123")
        #expect(context.isTestMode == true)
    }
}

private struct TestProcessor: EventProcessor {
    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.addParameter("customKey", value: "customValue")
        return try await next(input, context)
    }
}

@Suite(.serialized)
@MainActor
struct EntryPointIsolationTests {
    @Test
    @MainActor
    func newSessionRunsOffCallerActor() async throws {
        await TelemetryDeck.terminate()

        let record = ThreadRecord()
        let config = TelemetryDeck.Config(appID: "entry-point-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            logger: RecordingLogger(record: record),
            storage: InMemoryProcessorStorage()
        )

        await TelemetryDeck.newSession()

        #expect(record.wasCalledOnMainThread == false)

        await TelemetryDeck.terminate()
    }

    @Test
    @MainActor
    func isTestModeRunsOffCallerActor() async throws {
        await TelemetryDeck.terminate()

        let record = ThreadRecord()
        let config = TelemetryDeck.Config(appID: "entry-point-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [RecordingTestModeProcessor(record: record)],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            storage: InMemoryProcessorStorage()
        )

        _ = await TelemetryDeck.isTestMode()

        #expect(record.wasCalledOnMainThread == false)

        await TelemetryDeck.terminate()
    }

    @Test
    @MainActor
    func sessionIDRunsOffCallerActor() async throws {
        await TelemetryDeck.terminate()

        let record = ThreadRecord()
        let config = TelemetryDeck.Config(appID: "entry-point-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [RecordingSessionProcessor(record: record)],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            storage: InMemoryProcessorStorage()
        )

        _ = await TelemetryDeck.sessionID

        #expect(record.wasCalledOnMainThread == false)

        await TelemetryDeck.terminate()
    }

    @Test
    @MainActor
    func processorPipelineProcessRunsOffCallerActor() async throws {
        await TelemetryDeck.terminate()

        let record = ThreadRecord()
        let config = TelemetryDeck.Config(appID: "entry-point-test", namespace: "test")
        let finalizer = EventFinalizer(configuration: config)
        let pipeline = ProcessorPipeline(processors: [RecordingProcessor(record: record)], finalizer: finalizer)

        _ = try await pipeline.process(EventInput("Test.offMain"), context: EventContext())

        #expect(record.wasCalledOnMainThread == false)

        await TelemetryDeck.terminate()
    }
}

/// Guards a single boolean behind a lock; every access to `value` goes through the lock.
private nonisolated final class ThreadRecord: @unchecked Sendable {
    private let lock = NSLock()
    private var value = true

    var wasCalledOnMainThread: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func record() {
        lock.lock()
        defer { lock.unlock() }
        value = Thread.isMainThread
    }
}

private struct RecordingLogger: Logging {
    let record: ThreadRecord

    func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        record.record()
    }
}

private struct RecordingTestModeProcessor: TestModeProviding {
    let record: ThreadRecord

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        try await next(input, context)
    }

    func isTestMode() async -> Bool {
        record.record()
        return true
    }
}

private struct RecordingSessionProcessor: SessionManaging {
    let record: ThreadRecord

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        try await next(input, context)
    }

    func currentSessionID() async -> UUID {
        record.record()
        return UUID()
    }

    func startNewSession() async -> UUID {
        UUID()
    }
}

private struct RecordingProcessor: EventProcessor {
    let record: ThreadRecord

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        record.record()
        return try await next(input, context)
    }
}
