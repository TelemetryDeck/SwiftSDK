import Foundation

#if canImport(MetricKit) && (os(macOS) || os(iOS) || os(visionOS))
    import MetricKit

    class MetricKitClient: NSObject, MXMetricManagerSubscriber {
        var enabled: Bool = true {
            didSet {
                if enabled {
                    enableMetricKitReporting()
                } else {
                    disableMetricKitReporting()
                }
            }
        }

        func enableMetricKitReporting() {
            if #available(macOS 12.0, iOS 13.0, visionOS 1.0, *) {
                // Wait a few seconds before enabling MetricKit, to prevent
                // any race conditions and let the app settle down
                let seconds = 2.0
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                    MXMetricManager.shared.add(self)
                }
            }
        }

        func disableMetricKitReporting() {
            if #available(macOS 12.0, iOS 13.0, visionOS 1.0, *) {
                MXMetricManager.shared.remove(self)
            }
        }

        #if os(macOS)
        #else
            @available(iOS 13.0, visionOS 1.0, *)
            func didReceive(_ payloads: [MXMetricPayload]) {
                for payload in payloads {
                    guard let metricPayload = String(data: payload.jsonRepresentation(), encoding: .utf8) else { continue }
                    TelemetryManager.send("TelemetryDeck.Metrics.swiftMetric", with: ["metricPayload": metricPayload])
                }
            }
        #endif

        @available(macOS 12.0, iOS 14.0, visionOS 1.0, *)
        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                guard let diagnosticPayload = String(data: payload.jsonRepresentation(), encoding: .utf8) else { continue }
                TelemetryManager.send("TelemetryDeck.Crashes.swiftCrash", with: ["diagnisticPayload": diagnosticPayload])
            }
        }
    }
#else
    class MetricKitClient {
        var enabled: Bool {
            get { return false }
            set {}
        }
        
        func enableMetricKitReporting() {}
        func disableMetricKitReporting() {}
    }
#endif
