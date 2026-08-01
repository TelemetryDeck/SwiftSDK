import Foundation
import Testing

@testable import TelemetryDeck

struct DefaultPrefixProcessorTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")

    @Test
    func signalPrefixIsApplied() async throws {
        let processor = DefaultPrefixProcessor(eventPrefix: "MyApp.")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("UserAction")
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.type == "MyApp.UserAction")
    }

    @Test
    func parameterPrefixIsApplied() async throws {
        let processor = DefaultPrefixProcessor(parameterPrefix: "app.")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput(
            "Test.signal",
            parameters: [
                "customKey": "value",
                "anotherKey": 42,
            ]
        )
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.payload["app.customKey"] == "value")
        #expect(signal.payload["app.anotherKey"] == 42)
    }

    @Test
    func telemetryDeckParametersNotPrefixed() async throws {
        let processor = DefaultPrefixProcessor(parameterPrefix: "app.")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput(
            "Test.signal",
            parameters: [
                "TelemetryDeck.Device.modelName": "iPhone",
                "customKey": "value",
            ]
        )
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.payload["TelemetryDeck.Device.modelName"] == "iPhone")
        #expect(signal.payload["app.customKey"] == "value")
    }

    @Test
    func telemetryDeckSignalsNotPrefixed() async throws {
        let processor = DefaultPrefixProcessor(eventPrefix: "MyApp.")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("TelemetryDeck.Session.started")
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.type == "TelemetryDeck.Session.started")
    }

    @Test
    func noPrefixWhenProcessorHasNil() async throws {
        let processor = DefaultPrefixProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("UserAction", parameters: ["key": "value"])
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.type == "UserAction")
        #expect(signal.payload["key"] == "value")
    }

    @Test
    func signalAlreadyPrefixedNotDoublePrefixed() async throws {
        let processor = DefaultPrefixProcessor(eventPrefix: "MyApp.")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("MyApp.UserAction")
        let signal = try await pipeline.process(input, context: EventContext())

        #expect(signal.type == "MyApp.UserAction")
    }
}
