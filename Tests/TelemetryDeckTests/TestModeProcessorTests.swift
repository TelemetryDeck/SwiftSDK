import Foundation
import Testing

@testable import TelemetryDeck

struct TestModeProcessorTests {
    @Test
    func overrideTrueForceTestMode() async throws {
        let processor = TestModeProcessor(override: true)
        let isTest = await processor.isTestMode()
        #expect(isTest == true)
    }

    @Test
    func overrideFalseDisablesTestMode() async throws {
        let processor = TestModeProcessor(override: false)
        let isTest = await processor.isTestMode()
        #expect(isTest == false)
    }

    @Test
    func overrideNilUsesDebugFlag() async throws {
        let processor = TestModeProcessor(override: nil)
        let isTest = await processor.isTestMode()
        #if DEBUG
            #expect(isTest == true)
        #else
            #expect(isTest == false)
        #endif
    }

    @Test
    func testModePropagatedToSignalContext() async throws {
        let processor = TestModeProcessor(override: true)
        let configuration = TelemetryDeck.Config(appID: "test-app-id", namespace: "test")

        let capturer = ContextCapturingProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor, capturer],
            finalizer: EventFinalizer(configuration: configuration)
        )

        let input = EventInput("test.event")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let capturedTestMode = await capturer.capturedTestMode
        #expect(capturedTestMode == true)
    }
}

private actor ContextCapturingProcessor: EventProcessor {
    private(set) var capturedTestMode: Bool?

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        capturedTestMode = context.isTestMode
        return try await next(input, context)
    }
}
