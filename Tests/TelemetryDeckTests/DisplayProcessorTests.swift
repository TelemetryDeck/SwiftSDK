import Foundation
import Testing

@testable import TelemetryDeck

struct DisplayProcessorTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    private func run() async throws -> Event {
        let pipeline = ProcessorPipeline(
            processors: [DisplayProcessor()],
            finalizer: EventFinalizer(configuration: config)
        )
        return try await pipeline.process(EventInput("Display.test"), context: EventContext())
    }

    #if os(visionOS) || os(Linux)
        @Test
        func screenKeysAbsentOnVisionOS() async throws {
            let event = try await run()
            #expect(event.payload[DefaultParams.Screens.primaryWidth.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.primaryHeight.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.primaryResolution.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.allWidth.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.allHeight.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.allResolution.rawValue] == nil)
            #expect(event.payload[DefaultParams.Screens.allCount.rawValue] == nil)
        }
    #else
        @Test
        func primaryWidthAndHeightArePositiveIntegers() async throws {
            let event = try await run()

            guard case .int(let width) = event.payload[DefaultParams.Screens.primaryWidth.rawValue] else {
                Issue.record("primaryWidth not an int")
                return
            }
            guard case .int(let height) = event.payload[DefaultParams.Screens.primaryHeight.rawValue] else {
                Issue.record("primaryHeight not an int")
                return
            }
            #expect(width > 0)
            #expect(height > 0)
        }

        @Test
        func primaryResolutionMatchesWidthAndHeight() async throws {
            let event = try await run()

            guard case .int(let width) = event.payload[DefaultParams.Screens.primaryWidth.rawValue] else {
                Issue.record("primaryWidth missing or wrong type")
                return
            }
            guard case .int(let height) = event.payload[DefaultParams.Screens.primaryHeight.rawValue] else {
                Issue.record("primaryHeight missing or wrong type")
                return
            }
            guard case .string(let resolution) = event.payload[DefaultParams.Screens.primaryResolution.rawValue] else {
                Issue.record("primaryResolution missing or wrong type")
                return
            }
            #expect(resolution == "\(width),\(height)")
        }

        @Test
        func allCountMatchesArrayLengths() async throws {
            let event = try await run()

            guard case .int(let count) = event.payload[DefaultParams.Screens.allCount.rawValue] else {
                Issue.record("allCount not an int")
                return
            }
            #expect(count > 0)

            guard case .array(let widths) = event.payload[DefaultParams.Screens.allWidth.rawValue] else {
                Issue.record("allWidth not an array")
                return
            }
            guard case .array(let heights) = event.payload[DefaultParams.Screens.allHeight.rawValue] else {
                Issue.record("allHeight not an array")
                return
            }
            guard case .array(let resolutions) = event.payload[DefaultParams.Screens.allResolution.rawValue] else {
                Issue.record("allResolution not an array")
                return
            }
            #expect(widths.count == Int(count))
            #expect(heights.count == Int(count))
            #expect(resolutions.count == Int(count))
        }

        @Test
        func allArraysAreIndexAligned() async throws {
            let event = try await run()

            guard case .array(let widths) = event.payload[DefaultParams.Screens.allWidth.rawValue] else {
                Issue.record("allWidth not an array")
                return
            }
            guard case .array(let heights) = event.payload[DefaultParams.Screens.allHeight.rawValue] else {
                Issue.record("allHeight not an array")
                return
            }
            guard case .array(let resolutions) = event.payload[DefaultParams.Screens.allResolution.rawValue] else {
                Issue.record("allResolution not an array")
                return
            }

            for i in 0..<widths.count {
                guard case .int(let w) = widths[i], case .int(let h) = heights[i], case .string(let r) = resolutions[i] else {
                    Issue.record("Array element at index \(i) has wrong type")
                    return
                }
                #expect(r == "\(w),\(h)")
            }
        }

        @Test
        func primaryAppearsInAllArrays() async throws {
            let event = try await run()

            guard case .int(let primaryWidth) = event.payload[DefaultParams.Screens.primaryWidth.rawValue] else {
                Issue.record("primaryWidth missing or wrong type")
                return
            }
            guard case .int(let primaryHeight) = event.payload[DefaultParams.Screens.primaryHeight.rawValue] else {
                Issue.record("primaryHeight missing or wrong type")
                return
            }
            guard case .array(let widths) = event.payload[DefaultParams.Screens.allWidth.rawValue] else {
                Issue.record("allWidth not an array")
                return
            }
            guard case .array(let heights) = event.payload[DefaultParams.Screens.allHeight.rawValue] else {
                Issue.record("allHeight not an array")
                return
            }

            let widthInts = widths.compactMap { if case .int(let v) = $0 { v } else { nil } }
            let heightInts = heights.compactMap { if case .int(let v) = $0 { v } else { nil } }

            #expect(widthInts.contains(primaryWidth))
            #expect(heightInts.contains(primaryHeight))
        }

        @Test
        func deprecatedPointKeysPresent() async throws {
            let event = try await run()
            #expect(event.payload[DefaultParams.Device.screenResolutionWidth.rawValue] != nil)
            #expect(event.payload[DefaultParams.Device.screenResolutionHeight.rawValue] != nil)
        }
    #endif
}

struct DisplayProcessorCachingTests {
    private let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    private func runPipeline(processor: DisplayProcessor) async throws -> Event {
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )
        return try await pipeline.process(EventInput("Display.test"), context: EventContext())
    }

    #if !os(visionOS) && !os(Linux)
        @Test
        func secondEventIsServedFromCache() async throws {
            let clock = MutableClock()
            let processor = DisplayProcessor(dateProvider: clock.dateProvider)

            let first = try await runPipeline(processor: processor)
            let second = try await runPipeline(processor: processor)

            #expect(first.payload[DefaultParams.Screens.primaryWidth.rawValue] != nil)
            #expect(
                first.payload[DefaultParams.Screens.primaryWidth.rawValue]?.payloadValue
                    == second.payload[DefaultParams.Screens.primaryWidth.rawValue]?.payloadValue
            )
        }

        @Test
        func cacheIsReusedWithinCacheLifetime() async throws {
            let clock = MutableClock()
            let processor = DisplayProcessor(dateProvider: clock.dateProvider)

            let first = try await runPipeline(processor: processor)
            clock.advance(by: 3599)
            let second = try await runPipeline(processor: processor)

            #expect(
                first.payload[DefaultParams.Screens.primaryWidth.rawValue]?.payloadValue
                    == second.payload[DefaultParams.Screens.primaryWidth.rawValue]?.payloadValue
            )
        }

        @Test
        func cacheIsRefreshedAfterCacheLifetimeExpires() async throws {
            let clock = MutableClock()
            let processor = DisplayProcessor(dateProvider: clock.dateProvider)

            _ = try await runPipeline(processor: processor)
            clock.advance(by: 3601)
            let second = try await runPipeline(processor: processor)

            #expect(second.payload[DefaultParams.Screens.primaryWidth.rawValue] != nil)
        }

        @Test
        func testModeBypassesCache() async throws {
            let clock = MutableClock()
            let processor = DisplayProcessor(dateProvider: clock.dateProvider)

            var testContext = EventContext()
            testContext.isTestMode = true

            let pipeline = ProcessorPipeline(
                processors: [processor],
                finalizer: EventFinalizer(configuration: config)
            )

            let first = try await pipeline.process(EventInput("Display.test"), context: testContext)
            let second = try await pipeline.process(EventInput("Display.test"), context: testContext)

            #expect(first.payload[DefaultParams.Screens.primaryWidth.rawValue] != nil)
            #expect(second.payload[DefaultParams.Screens.primaryWidth.rawValue] != nil)
        }
    #endif
}

struct PayloadValueArrayRoundTripTests {
    @Test
    func intArrayEncodesAsNativeJSONArray() throws {
        let value = PayloadValue.array([.int(480), .int(768)])
        let data = try JSONEncoder().encode(value)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("["))
        #expect(json.contains("480"))
        #expect(json.contains("768"))
        #expect(!json.contains("\""))
    }

    @Test
    func stringArrayEncodesAsNativeJSONArray() throws {
        let value = PayloadValue.array([.string("480,768"), .string("1920,1080")])
        let data = try JSONEncoder().encode(value)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("["))
        #expect(json.contains("480,768"))
        #expect(json.contains("1920,1080"))
    }

    @Test
    func intArrayRoundTrips() throws {
        let original = PayloadValue.array([.int(480), .int(768)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func stringArrayRoundTrips() throws {
        let original = PayloadValue.array([.string("480,768"), .string("1920,1080")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(decoded == original)
    }
}
