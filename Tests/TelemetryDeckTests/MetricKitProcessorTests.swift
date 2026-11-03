import Foundation
import Testing

@testable import TelemetryDeck

#if canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
    import MetricKit

    @Suite
    struct MetricKitProcessorTests {
        private static let fixtureJSON = """
            {
              "timeRange": {"begin": 0, "end": 3600},
              "stateEntries": [
                {
                  "state": {
                    "domain": "com.telemetrydeck.feature",
                    "label": "premium",
                    "duration": {"value": 120.0, "unit": "s"},
                    "stableMetadata": {}
                  },
                  "values": [
                    {"cpuTimeMetric": {"value": {"value": 5.0, "unit": "s"}}}
                  ]
                }
              ],
              "intervalEntries": [
                {
                  "states": [],
                  "duration": {"value": 86400.0, "unit": "s"},
                  "values": [
                    {"cpuTimeMetric": {"value": {"value": 42.0, "unit": "s"}}},
                    {
                      "hangTimeMetric": {
                        "histogram": {
                          "buckets": [
                            {"lowerBound": {"value": 0.0, "unit": "s"}, "upperBound": {"value": 1.0, "unit": "s"}, "count": 5}
                          ]
                        }
                      }
                    }
                  ]
                }
              ]
            }
            """

        @available(iOS 27, macOS 27, macCatalyst 27, *)
        private static func makeFixtureReport() throws -> MetricReport {
            try JSONDecoder().decode(MetricReport.self, from: Data(fixtureJSON.utf8))
        }

        @Test
        @available(iOS 27, macOS 27, macCatalyst 27, *)
        func sendMetricReportEmitsSingleEvent() async throws {
            let report = try Self.makeFixtureReport()
            let processor = MetricKitProcessor()
            let emitter = CapturingEventSender()
            await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)

            await processor.send(metricReport: report)

            let sentEvents = await emitter.sentEvents
            #expect(sentEvents.count == 1)
            #expect(sentEvents.first?.name == DefaultEvents.Performance.metricKitMetricReport.rawValue)
        }

        @Test
        @available(iOS 27, macOS 27, macCatalyst 27, *)
        func sendMetricReportIncludesSingleJSONParameter() async throws {
            let report = try Self.makeFixtureReport()
            let processor = MetricKitProcessor()
            let emitter = CapturingEventSender()
            await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)

            await processor.send(metricReport: report)

            let event = try #require(await emitter.sentEvents.first)
            #expect(event.parameters.count == 1)

            let value = try #require(event.parameters[DefaultParams.Performance.metricKitMetricReport.rawValue]?.payloadValue)
            let jsonValue: String? = if case .string(let string) = value { string } else { nil }
            let json = try #require(jsonValue)

            let decodedReport = try JSONDecoder().decode(MetricReport.self, from: Data(json.utf8))
            #expect(decodedReport.stateEntries.count == 1)
            #expect(decodedReport.stateEntries.first?.state.domain == "com.telemetrydeck.feature")

            let cpuTimeValues = decodedReport.intervalEntries.fullDayEntry.values.compactMap { value -> Measurement<UnitDuration>? in
                guard case .cpuTime(let metric) = value else { return nil }
                return metric.value
            }
            let cpuTimeValue = try #require(cpuTimeValues.first)
            #expect(cpuTimeValue.converted(to: .baseUnit()).value == 42.0)
        }

        @Test
        @available(iOS 27, macOS 27, macCatalyst 27, *)
        func sendMetricReportWithoutStartDropsReport() async throws {
            let report = try Self.makeFixtureReport()
            let processor = MetricKitProcessor()

            await processor.send(metricReport: report)

            let emitter = CapturingEventSender()
            await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)
            await processor.send(metricReport: report)

            let sentEvents = await emitter.sentEvents
            #expect(sentEvents.count == 1)
        }
    }
#endif
