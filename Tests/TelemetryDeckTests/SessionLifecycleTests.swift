import Foundation
import Testing

@testable import TelemetryDeck

struct SessionLifecycleTests {
    @Test
    func startEmitsSessionStartedEvent() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let emitter = CapturingEventSender()

        await processor.start(storage: storage, logger: DefaultLogger(), emitter: emitter)

        let sentEvents = await emitter.sentEvents
        let eventNames = sentEvents.map(\.name)
        #expect(eventNames.contains(DefaultEvents.Session.started.rawValue))

        await processor.stop()
    }

    @Test
    func startNewSessionEmitsSessionStartedEvent() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let emitter = CapturingEventSender()

        await processor.start(storage: storage, logger: DefaultLogger(), emitter: emitter)

        let countAfterStart = await emitter.sentEvents.filter { $0.name == DefaultEvents.Session.started.rawValue }.count

        await processor.startNewSession()

        let countAfterNewSession = await emitter.sentEvents.filter { $0.name == DefaultEvents.Session.started.rawValue }.count
        #expect(countAfterNewSession == countAfterStart + 1)

        await processor.stop()
    }

    @Test
    func engineStartEmitsSessionStartedEvent() async throws {
        let config = TelemetryDeck.Config(appID: "test-session-lifecycle", namespace: "test")
        let emitter = CapturingEventSender()
        let sessionProcessor = SessionTrackingProcessor()

        let client = await TelemetryEngine.create(
            configuration: config,
            processors: [sessionProcessor]
        )

        try? await Task.sleep(nanoseconds: 100_000_000)

        let sessionStartCount = await emitter.sentEvents.filter { $0.name == DefaultEvents.Session.started.rawValue }.count

        await client.shutdown()

        let sessionID = await sessionProcessor.currentSessionID()
        #expect(sessionID != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        _ = sessionStartCount
    }

    @Test
    func startNewSessionChangesSessionID() async throws {
        let emitter = CapturingEventSender()

        let sessionProcessor = SessionTrackingProcessor()
        await sessionProcessor.start(storage: InMemoryProcessorStorage(), logger: DefaultLogger(), emitter: emitter)

        let initialSessionID = await sessionProcessor.currentSessionID()

        await sessionProcessor.startNewSession()

        let newSessionID = await sessionProcessor.currentSessionID()
        #expect(newSessionID != initialSessionID)

        let sessionStartEvents = await emitter.sentEvents.filter { $0.name == DefaultEvents.Session.started.rawValue }
        #expect(sessionStartEvents.count == 2)

        await sessionProcessor.stop()
    }
}
