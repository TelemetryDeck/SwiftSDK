import Foundation

#if canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
    import MetricKit

    /// An event processor that can convert a MetricKit performance report into a TelemetryDeck event.
    @available(iOS 27, macOS 27, macCatalyst 27, *)
    public protocol MetricReportProcessing: EventProcessor {
        func send(metricReport: MetricReport) async
    }
#endif
