import Foundation
import Testing

@testable import TelemetryDeck

struct UserIdentifierProcessorTests {
    @Test
    func customUserIDFromInputTakesPrecedence() async throws {
        let processor = UserIdentifierProcessor()
        let storage = InMemoryProcessorStorage()
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        await processor.start(storage: storage, logger: NoOpLogger(), emitter: MockEventSender())
        await processor.setUserIdentifier("explicit")

        let capturer = ContextCapturingProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor, capturer],
            finalizer: EventFinalizer(configuration: configuration)
        )

        let input = EventInput("test.event", customUserID: "custom")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let capturedIdentifier = await capturer.capturedUserIdentifier
        #expect(capturedIdentifier == "custom")
    }

    @Test
    func explicitUserIDUsedWhenNoCustomID() async throws {
        let processor = UserIdentifierProcessor()
        let storage = InMemoryProcessorStorage()
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        await processor.start(storage: storage, logger: NoOpLogger(), emitter: MockEventSender())
        await processor.setUserIdentifier("explicit")

        let capturer = ContextCapturingProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor, capturer],
            finalizer: EventFinalizer(configuration: configuration)
        )

        let input = EventInput("test.event")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let capturedIdentifier = await capturer.capturedUserIdentifier
        #expect(capturedIdentifier == "explicit")
    }

    @Test
    func defaultUserIDUsedWhenNoExplicitOrCustom() async throws {
        let processor = UserIdentifierProcessor()
        let storage = InMemoryProcessorStorage()
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        await processor.start(storage: storage, logger: NoOpLogger(), emitter: MockEventSender())

        let capturer = ContextCapturingProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor, capturer],
            finalizer: EventFinalizer(configuration: configuration)
        )

        let input = EventInput("test.event")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let capturedIdentifier = await capturer.capturedUserIdentifier
        #expect(capturedIdentifier != nil)
        #expect(capturedIdentifier != "")
    }

    @Test
    func setUserIdentifierToNilReverts() async throws {
        let processor = UserIdentifierProcessor()
        let storage = InMemoryProcessorStorage()
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        await processor.start(storage: storage, logger: NoOpLogger(), emitter: MockEventSender())
        await processor.setUserIdentifier("explicit")
        await processor.setUserIdentifier(nil)

        let capturer = ContextCapturingProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor, capturer],
            finalizer: EventFinalizer(configuration: configuration)
        )

        let input = EventInput("test.event")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let capturedIdentifier = await capturer.capturedUserIdentifier
        #expect(capturedIdentifier != "explicit")
        #expect(capturedIdentifier != nil)
    }

    @Test
    func currentUserIdentifierReflectsState() async throws {
        let processor = UserIdentifierProcessor()
        let storage = InMemoryProcessorStorage()
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        await processor.start(storage: storage, logger: NoOpLogger(), emitter: MockEventSender())

        let defaultID = await processor.currentUserIdentifier()
        #expect(defaultID != nil)

        await processor.setUserIdentifier("explicit")
        let explicitID = await processor.currentUserIdentifier()
        #expect(explicitID == "explicit")

        await processor.setUserIdentifier(nil)
        let revertedID = await processor.currentUserIdentifier()
        #expect(revertedID == defaultID)
    }
}

private actor ContextCapturingProcessor: EventProcessor {
    private(set) var capturedUserIdentifier: String?

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        capturedUserIdentifier = context.userIdentifier
        return try await next(input, context)
    }
}
