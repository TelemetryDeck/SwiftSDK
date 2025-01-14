#if canImport(WatchKit)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@available(watchOS 7.0, *)
final class DurationSignalTracker: @unchecked Sendable {
    static let shared = DurationSignalTracker()

    private struct CachedData: Sendable {
        let startTime: Date
        let parameters: [String: String]
    }

    private let queue = DispatchQueue(label: "com.telemetrydeck.DurationSignalTracker")
    private var startedSignals: [String: CachedData] = [:]
    private var lastEnteredBackground: Date?

    private init() {
        self.setupAppLifecycleObservers()
    }

    func startTracking(_ signalName: String, parameters: [String: String]) {
        self.queue.sync {
            self.startedSignals[signalName] = CachedData(startTime: Date(), parameters: parameters)
        }
    }

    func stopTracking(_ signalName: String) -> (duration: TimeInterval, parameters: [String: String])? {
        self.queue.sync {
            guard let trackingData = self.startedSignals[signalName] else { return nil }
            self.startedSignals[signalName] = nil

            let duration = Date().timeIntervalSince(trackingData.startTime)
            return (duration, trackingData.parameters)
        }
    }

    private func setupAppLifecycleObservers() {
        #if canImport(WatchKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackgroundNotification),
            name: WKApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForegroundNotification),
            name: WKApplication.willEnterForegroundNotification,
            object: nil
        )
        #elseif canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #elseif canImport(AppKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackgroundNotification),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForegroundNotification),
            name: NSApplication.willBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc
    private func handleDidEnterBackgroundNotification() {
        self.queue.sync {
            self.lastEnteredBackground = Date()
        }
    }

    @objc
    private func handleWillEnterForegroundNotification() {
        self.queue.sync {
            guard let lastEnteredBackground else { return }
            let backgroundDuration = Date().timeIntervalSince(lastEnteredBackground)

            for (signalName, data) in self.startedSignals {
                self.startedSignals[signalName] = CachedData(
                    startTime: data.startTime.addingTimeInterval(backgroundDuration),
                    parameters: data.parameters
                )
            }

            self.lastEnteredBackground = nil
        }
    }
}
