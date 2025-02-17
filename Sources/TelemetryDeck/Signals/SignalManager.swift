import Foundation

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#elseif os(tvOS)
import TVUIKit
#endif

protocol SignalManageable {
    func processSignal(_ signalName: String, parameters: [String: String], floatValue: Double?, customUserID: String?, configuration: TelemetryManagerConfiguration)
    func attemptToSendNextBatchOfCachedSignals()

    @MainActor var defaultUserIdentifier: String { get }
}

final class SignalManager: SignalManageable, @unchecked Sendable {
    static let minimumSecondsToPassBetweenRequests: Double = 10

    private var signalCache: SignalCache<SignalPostBody>
    let configuration: TelemetryManagerConfiguration

    private var sendTimer: Timer?

    init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration

        // We automatically load any old signals from disk on initialisation
        signalCache = SignalCache(logHandler: configuration.swiftUIPreviewMode ? nil : configuration.logHandler)

        // Before the app terminates, we want to save any pending signals to disk
        // We need to monitor different notifications for different devices.
        // macOS - We can simply wait for the app to terminate at which point we get enough time to save the cache
        // which is then restored when the app is cold started and all init's fire.
        // iOS - App termination is an unreliable method to do work, so we use moving to background and foreground to save/load the cache.
        // watchOS and tvOS - We can only really monitor moving to background and foreground to save/load the cache.
        // watchOS pre7.0 - Doesn't have any kind of notification to monitor.
        #if os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
        #elseif os(watchOS)
        if #available(watchOS 7.0, *) {
            // We need to use a delay with these type of notifications because they fire on app load which causes a double load of the cache from disk
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: WKExtension.applicationWillEnterForegroundNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterBackground), name: WKExtension.applicationDidEnterBackgroundNotification, object: nil)
            }
        } else {
            // Pre watchOS 7.0, this library will not use disk caching at all as there are no notifications we can observe.
        }
        #elseif os(tvOS) || os(iOS) || os(visionOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // We need to use a delay with these type of notifications because they fire on app load which causes a double load of the cache from disk
            NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        #endif

        sendCachedSignalsRepeatedly()
    }

    /// Send any cached Signals from previous sessions now and setup a timer to repeatedly send Signals from cache in regular time intervals.
    private func sendCachedSignalsRepeatedly() {
        attemptToSendNextBatchOfCachedSignals()

        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(timeInterval: Self.minimumSecondsToPassBetweenRequests, target: self, selector: #selector(attemptToSendNextBatchOfCachedSignals), userInfo: nil, repeats: true)
    }

    /// Adds a signal to the process queue
    func processSignal(
        _ signalName: String,
        parameters: [String: String],
        floatValue: Double?,
        customUserID: String?,
        configuration: TelemetryManagerConfiguration
    ) {
        // enqueue signal to sending cache
        DispatchQueue.main.async {
            let defaultUserIdentifier = self.defaultUserIdentifier
            let defaultParameters = DefaultSignalPayload.parameters

            DispatchQueue.global(qos: .utility).async {
                let enrichedMetadata: [String: String] = configuration.metadataEnrichers
                    .map { $0.enrich(signalType: signalName, for: customUserID, floatValue: floatValue) }
                    .reduce([String: String]()) { $0.applying($1) }

                let payload = defaultParameters
                    .applying(enrichedMetadata)
                    .applying(parameters)

                let signalPostBody = SignalPostBody(
                    receivedAt: Date(),
                    appID: configuration.telemetryAppID,
                    clientUser: CryptoHashing.sha256(string: customUserID ?? defaultUserIdentifier, salt: configuration.salt),
                    sessionID: configuration.sessionID.uuidString,
                    type: "\(signalName)",
                    floatValue: floatValue,
                    payload: payload,
                    isTestMode: configuration.testMode ? "true" : "false"
                )

                configuration.logHandler?.log(.debug, message: "Process signal: \(signalPostBody)")

                self.signalCache.push(signalPostBody)
            }
        }
    }

    /// Sends one batch of signals from the cache if not empty.
    /// If signals fail to send, we put them back into the cache to try again later.
    @objc
    @Sendable
    func attemptToSendNextBatchOfCachedSignals() {
        configuration.logHandler?.log(.debug, message: "Current signal cache count: \(signalCache.count())")

        let queuedSignals: [SignalPostBody] = signalCache.pop()
        if !queuedSignals.isEmpty {
            configuration.logHandler?.log(message: "Sending \(queuedSignals.count) signals leaving a cache of \(signalCache.count()) signals")

            send(queuedSignals) { [configuration, signalCache] data, response, error in

                if let error = error {
                    configuration.logHandler?.log(.error, message: "\(error)")

                    // The send failed, put the signal back into the queue
                    signalCache.push(queuedSignals)
                    return
                }

                // Check for valid status code response
                guard response?.statusCodeError() == nil else {
                    let statusError = response!.statusCodeError()!
                    configuration.logHandler?.log(.error, message: "\(statusError)")
                    // The send failed, put the signal back into the queue
                    signalCache.push(queuedSignals)
                    return
                }

                if let data = data, let messageString = String(data: data, encoding: .utf8) {
                    configuration.logHandler?.log(.debug, message: messageString)
                }
            }
        }
    }
}

// MARK: - Notifications

private extension SignalManager {
    @MainActor
    @objc func appWillTerminate() {
        configuration.logHandler?.log(.debug, message: #function)

        #if os(watchOS) || os(macOS)
        self.signalCache.backupCache()
        #else
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            // we're in an app extension, where `UIApplication.shared` is not available
            self.signalCache.backupCache()
        } else {
            // run backup in background task to avoid blocking main thread while ensuring app stays open during write
            let backgroundTaskID = UIApplication.shared.beginBackgroundTask()
            DispatchQueue.global(qos: .background).async {
                self.signalCache.backupCache()

                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        }
        #endif
    }

    /// WatchOS doesn't have a notification before it's killed, so we have to use background/foreground
    /// This means our `init()` above doesn't always run when coming back to foreground, so we have to manually
    /// reload the cache. This also means we miss any signals sent during watchDidEnterForeground
    /// so we merge them into the new cache.
    #if os(watchOS) || os(tvOS) || os(iOS) || os(visionOS)
    @objc func didEnterForeground() {
        configuration.logHandler?.log(.debug, message: #function)

        let currentCache = signalCache.pop()
        configuration.logHandler?.log(.debug, message: "current cache is \(currentCache.count) signals")
        signalCache = SignalCache(logHandler: configuration.logHandler)
        signalCache.push(currentCache)

        sendCachedSignalsRepeatedly()
    }

    @MainActor
    @objc func didEnterBackground() {
        configuration.logHandler?.log(.debug, message: #function)

        sendTimer?.invalidate()
        sendTimer = nil

        #if os(watchOS) || os(macOS)
        self.signalCache.backupCache()
        #else
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            // we're in an app extension, where `UIApplication.shared` is not available
            self.signalCache.backupCache()
        } else {
            // run backup in background task to avoid blocking main thread while ensuring app stays open during write
            let backgroundTaskID = UIApplication.shared.beginBackgroundTask()
            DispatchQueue.global(qos: .background).async {
                self.signalCache.backupCache()

                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        }
        #endif
    }
    #endif
}

// MARK: - Comms

private extension SignalManager {
    private func send(_ signalPostBodies: [SignalPostBody], completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let subpath: String
            if let namespace = self.configuration.namespace, !namespace.isEmpty {
                subpath = "/v2/namespace/\(namespace)/"
            } else {
                subpath = "/v2/"
            }
            let url = self.configuration.apiBaseURL.appendingPathComponent(subpath)

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

            guard let body = try? JSONEncoder.telemetryEncoder.encode(signalPostBodies) else {
                return
            }

            urlRequest.httpBody = body

            if let data = urlRequest.httpBody, let messageString = String(data: data, encoding: .utf8) {
                self.configuration.logHandler?.log(.debug, message: messageString)
            }

            let task = self.configuration.urlSession.dataTask(with: urlRequest, completionHandler: completionHandler)
            task.resume()
        }
    }
}

// MARK: - Helpers

extension SignalManager {
    /// The default user identifier. If the platform supports it, the ``identifierForVendor``. Otherwise, a self-generated `UUID` which is persisted in custom `UserDefaults` if available.
    @MainActor
    var defaultUserIdentifier: String {
        guard configuration.defaultUser == nil else { return configuration.defaultUser! }

        #if os(iOS) || os(tvOS) || os(visionOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown user \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
        #elseif os(watchOS)
        if #available(watchOS 6.2, *) {
            return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown user \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
        } else {
            return "unknown user \(DefaultSignalPayload.platform) \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
        }
        #elseif os(macOS)
        if let customDefaults = TelemetryDeck.customDefaults, let defaultUserIdentifier = customDefaults.string(forKey: "defaultUserIdentifier") {
            return defaultUserIdentifier
        } else {
            let defaultUserIdentifier = UUID().uuidString
            TelemetryDeck.customDefaults?.set(defaultUserIdentifier, forKey: "defaultUserIdentifier")
            return defaultUserIdentifier
        }
        #else
        #if DEBUG
        let line1 = "[Telemetry] On this platform, Telemetry can't generate a unique user identifier."
        let line2 = "It is recommended you supply one yourself. More info: https://telemetrydeck.com/pages/signal-reference.html"
        configuration.logHandler?.log(message: "\(line1) \(line2)")
        #endif
        return "unknown user \(DefaultSignalPayload.platform) \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
        #endif
    }
}

private extension URLResponse {
    /// Returns the HTTP status code
    func statusCode() -> Int? {
        if let httpResponse = self as? HTTPURLResponse {
            return httpResponse.statusCode
        }
        return nil
    }

    /// Returns an `Error` if not a valid statusCode
    func statusCodeError() -> Error? {
        // Check for valid response in the 200-299 range
        guard (200 ... 299).contains(statusCode() ?? 0) else {
            if statusCode() == 401 {
                return TelemetryError.unauthorised
            } else if statusCode() == 403 {
                return TelemetryError.forbidden
            } else if statusCode() == 413 {
                return TelemetryError.payloadTooLarge
            } else {
                return TelemetryError.invalidStatusCode(statusCode: statusCode() ?? 0)
            }
        }
        return nil
    }
}

// MARK: - Errors

private enum TelemetryError: Error {
    case unauthorised
    case forbidden
    case payloadTooLarge
    case invalidStatusCode(statusCode: Int)
}

extension TelemetryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidStatusCode(let statusCode):
            return "Invalid status code \(statusCode)"
        case .unauthorised:
            return "Unauthorized (401)"
        case .forbidden:
            return "Forbidden (403)"
        case .payloadTooLarge:
            return "Payload is too large (413)"
        }
    }
}
