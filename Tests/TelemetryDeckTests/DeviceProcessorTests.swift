import Foundation
import Testing

@testable import TelemetryDeck

struct DeviceProcessorTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")

    #if os(visionOS)
        @Test
        func modelNameIsNotArchitectureOnVisionOS() async throws {
            let processor = DeviceProcessor()
            let pipeline = ProcessorPipeline(
                processors: [processor],
                finalizer: EventFinalizer(configuration: config)
            )

            let event = try await pipeline.process(EventInput("App.launched"), context: EventContext())
            let modelName = try #require(event.payload[DefaultParams.Device.modelName.rawValue])

            guard case .string(let value) = modelName else {
                Issue.record("modelName was not a string payload value")
                return
            }
            #expect(!value.isEmpty)
            #expect(value != "arm64")
            #expect(value != "x86_64")
        }
    #endif
}
