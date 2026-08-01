import Foundation
import Testing

@testable import TelemetryDeck

struct NewInstallProcessorTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    @Test
    func firstStartEmitsNewInstallEvent() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()
        let emitter = CapturingEventSender()

        await processor.start(storage: storage, logger: logger, emitter: emitter)

        let sentEvents = await emitter.sentEvents
        let eventNames = sentEvents.map(\.name)
        #expect(eventNames.contains(DefaultEvents.Acquisition.newInstallDetected.rawValue))

        await processor.stop()
    }

    @Test
    func firstSignalIncludesNewInstallParameter() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("Test.signal")
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.payload["TelemetryDeck.Acquisition.isNewInstall"] == true)

        await processor.stop()
    }

    @Test
    func secondSignalOmitsNewInstallParameter() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let signal1 = try await pipeline.process(EventInput("First.signal"), context: EventContext())
        #expect(signal1.payload["TelemetryDeck.Acquisition.isNewInstall"] == true)

        let signal2 = try await pipeline.process(EventInput("Second.signal"), context: EventContext())
        #expect(signal2.payload["TelemetryDeck.Acquisition.isNewInstall"] == nil)

        await processor.stop()
    }

    @Test
    func subsequentStartDoesNotEmitNewInstallEvent() async throws {
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await storage.set("existing-install-id", forKey: "installID")

        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let emitter = CapturingEventSender()

        await processor.start(storage: storage, logger: logger, emitter: emitter)

        let sentEvents = await emitter.sentEvents
        let eventNames = sentEvents.map(\.name)
        #expect(!eventNames.contains(DefaultEvents.Acquisition.newInstallDetected.rawValue))

        await processor.stop()
    }
}
