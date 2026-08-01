import Foundation
import Testing

@testable import TelemetryDeck

struct DefaultParametersProcessorTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")

    @Test
    func defaultParametersAreMergedIntoEvent() async throws {
        let processor = DefaultParametersProcessor(parameters: ["environment": "staging", "region": "eu"])
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("App.launched")
        let event = try await pipeline.process(input, context: EventContext())

        #expect(event.payload["environment"] == "staging")
        #expect(event.payload["region"] == "eu")
    }

    @Test
    func userParametersOverrideDefaults() async throws {
        let processor = DefaultParametersProcessor(parameters: ["tier": "free"])
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("App.launched", parameters: ["tier": "premium"])
        let event = try await pipeline.process(input, context: EventContext())

        #expect(event.payload["tier"] == "premium")
    }

    @Test
    func defaultParametersGetPrefixed() async throws {
        let pipeline = ProcessorPipeline(
            processors: [
                DefaultParametersProcessor(parameters: ["tier": "free"]),
                DefaultPrefixProcessor(parameterPrefix: "app."),
            ],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("App.launched")
        let event = try await pipeline.process(input, context: EventContext())

        #expect(event.payload["app.tier"] == "free")
        #expect(event.payload["tier"] == nil)
    }

    @Test
    func emptyDefaultParametersHasNoEffect() async throws {
        let processor = DefaultParametersProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("App.launched", parameters: ["key": "value"])
        let event = try await pipeline.process(input, context: EventContext())

        #expect(event.payload["key"] == "value")
        #expect(event.payload.count == 1)
    }
}
