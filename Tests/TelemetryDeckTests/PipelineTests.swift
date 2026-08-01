import Testing

@testable import TelemetryDeck

struct PipelineTests {
    let testConfig = TelemetryDeck.Config(appID: "test-app-id", namespace: "test-ns")

    @Test
    func emptyProcessorsPipeline() async throws {
        let pipeline = ProcessorPipeline(
            processors: [],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)
        #expect(signal.type == "Test.signal")
        #expect(signal.appID == "test-app-id")
    }

    @Test
    func processorMutatesContext() async throws {
        let processor = ParameterAddingProcessor(key: "testKey", value: "testValue")
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)
        #expect(signal.payload["testKey"] == "testValue")
    }

    @Test
    func processorsCalledInOrder() async throws {
        let processor1 = ParameterAddingProcessor(key: "param1", value: "value1")
        let processor2 = ParameterAddingProcessor(key: "param2", value: "value2")
        let pipeline = ProcessorPipeline(
            processors: [processor1, processor2],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)
        #expect(signal.payload["param1"] == "value1")
        #expect(signal.payload["param2"] == "value2")
    }

    @Test
    func eventFilteredStopsChain() async throws {
        let processor = FilteringProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()

        do {
            _ = try await pipeline.process(input, context: context)
            Issue.record("Expected eventFiltered error to be thrown")
        } catch let error as ProcessorError {
            switch error {
            case .eventFiltered:
                break
            default:
                Issue.record("Expected eventFiltered, got \(error)")
            }
        }
    }

    @Test
    func finalizerHashesUserIdentifier() async throws {
        let pipeline = ProcessorPipeline(
            processors: [],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        var context = EventContext()
        context.userIdentifier = "test@example.com"
        let signal = try await pipeline.process(input, context: context)
        let expectedHash = CryptoHashing.sha256(string: "test@example.com", salt: "")
        #expect(signal.clientUser == expectedHash)
    }

    @Test
    func finalizerMergesParameters() async throws {
        let pipeline = ProcessorPipeline(
            processors: [],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        var context = EventContext()
        context.addParameter("paramA", value: "contextValue")
        context.addParameter("paramB", value: "onlyInContext")

        let input = EventInput(
            "Test.signal",
            parameters: [
                "paramA": "inputValue",
                "paramC": "onlyInInput",
            ]
        )

        let signal = try await pipeline.process(input, context: context)
        #expect(signal.payload["paramA"] == "inputValue")
        #expect(signal.payload["paramB"] == "onlyInContext")
        #expect(signal.payload["paramC"] == "onlyInInput")
    }
}

private struct ParameterAddingProcessor: EventProcessor {
    let key: String
    let value: String

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.addParameter(key, value: value)
        return try await next(input, context)
    }
}

private struct FilteringProcessor: EventProcessor {
    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        throw ProcessorError.eventFiltered
    }
}
