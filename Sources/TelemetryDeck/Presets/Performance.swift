import Foundation

#if canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
    import MetricKit

    extension TelemetryDeck {
        /// Sends a MetricKit performance report as a single `TelemetryDeck.Performance.metricKitMetricReport` event.
        ///
        /// This must be called after `initialize()`;
        @available(iOS 27, macOS 27, macCatalyst 27, *)
        public static func send(metricReport: MetricReport) async {
            guard let client = await client() else {
                await log(.error, "TelemetryDeck not initialized")
                return
            }
            guard let processor = await client.processor(conformingTo: (any MetricReportProcessing).self) else {
                await log(.error, "No MetricReportProcessing processor in pipeline")
                return
            }
            await processor.send(metricReport: metricReport)
        }

        /// Sends a MetricKit performance report without awaiting completion; suitable for fire-and-forget usage.
        @available(iOS 27, macOS 27, macCatalyst 27, *)
        public static func send(metricReport: MetricReport) {
            Task { await send(metricReport: metricReport) }
        }
    }
#endif
