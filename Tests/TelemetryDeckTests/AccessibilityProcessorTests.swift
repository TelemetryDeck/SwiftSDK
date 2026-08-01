import Foundation
import Testing

@testable import TelemetryDeck

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct AccessibilityProcessorTests {
    #if os(iOS) || os(tvOS) || os(visionOS)
        @Test
        func leftToRightDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .leftToRight) == "leftToRight")
        }

        @Test
        func rightToLeftDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .rightToLeft) == "rightToLeft")
        }
    #elseif os(macOS)
        @Test
        func leftToRightDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .leftToRight) == "leftToRight")
        }

        @Test
        func rightToLeftDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .rightToLeft) == "rightToLeft")
        }
    #endif
}

struct AccessibilityProcessorCacheInvalidationTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    #if os(macOS)
        @Test
        func screenParameterNotificationInvalidatesCache() async throws {
            let clock = MutableClock()
            let processor = AccessibilityProcessor(dateProvider: clock.dateProvider)
            await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())

            let pipeline = ProcessorPipeline(
                processors: [processor],
                finalizer: EventFinalizer(configuration: config)
            )
            _ = try await pipeline.process(EventInput("Accessibility.test"), context: EventContext())
            let populated = await processor.hasCachedParamsForTesting
            #expect(populated)

            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

            var cleared = false
            for _ in 0..<200 {
                await Task.yield()
                if await !processor.hasCachedParamsForTesting {
                    cleared = true
                    break
                }
            }
            #expect(cleared)

            await processor.stop()
        }

        @Test
        func stopRemovesObserverSoCacheIsNotInvalidated() async throws {
            let clock = MutableClock()
            let processor = AccessibilityProcessor(dateProvider: clock.dateProvider)
            await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())
            await processor.stop()

            let pipeline = ProcessorPipeline(
                processors: [processor],
                finalizer: EventFinalizer(configuration: config)
            )
            _ = try await pipeline.process(EventInput("Accessibility.test"), context: EventContext())
            #expect(await processor.hasCachedParamsForTesting)

            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

            for _ in 0..<20 { await Task.yield() }
            #expect(await processor.hasCachedParamsForTesting)
        }
    #endif
}
