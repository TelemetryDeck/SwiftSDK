import Foundation

#if canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
    import MetricKit

    /// Converts MetricKit performance reports into a single `TelemetryDeck.Performance.metricKitMetricReport` event.
    @available(iOS 27, macOS 27, macCatalyst 27, *)
    public actor MetricKitProcessor: EventProcessor, MetricReportProcessing {
        private var logger: (any Logging)?
        private var emitter: (any EventSending)?

        /// Creates a MetricKit processor.
        public init() {}

        /// Stores the logger and event emitter used when converting and sending reports.
        public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
            self.logger = logger
            self.emitter = emitter
        }

        /// Releases the logger and event emitter references.
        public func stop() async {
            logger = nil
            emitter = nil
        }

        /// Passes events through unmodified.
        public func process(
            _ input: EventInput,
            context: EventContext,
            next: @Sendable (EventInput, EventContext) async throws -> Event
        ) async throws -> Event {
            try await next(input, context)
        }

        /// Serializes the given MetricKit report to JSON and sends it as the value of a single
        /// `TelemetryDeck.Performance.metricKitMetricReport` parameter on a `TelemetryDeck.Performance.metricKitMetricReport` event.
        public func send(metricReport report: MetricReport) async {
            guard let emitter else {
                logger?.log(.error, "MetricKitProcessor has not been started; dropping metric report")
                return
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

            let reportData: Data
            do {
                reportData = try encoder.encode(report)
            } catch {
                logger?.log(.error, "Failed to encode metric report: \(error)")
                return
            }

            let reportJSON = String(decoding: reportData, as: UTF8.self)

            var parameters = EventParameters()
            parameters[DefaultParams.Performance.metricKitMetricReport] = reportJSON

            await emitter.send(
                EventInput(
                    DefaultEvents.Performance.metricKitMetricReport.rawValue,
                    parameters: parameters,
                    skipsReservedPrefixValidation: true
                )
            )
        }
    }
#endif
