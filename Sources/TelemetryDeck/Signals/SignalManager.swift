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
    func processSignal(
        _ signalName: String,
        parameters: [String: String],
        floatValue: Double?,
        customUserID: String?,
        configuration: TelemetryManagerConfiguration
    )
    func attemptToSendNextBatchOfCachedSignals()

    @MainActor var defaultUserIdentifier: String { get }
}

final class SignalManager: SignalManageable, @unchecked Sendable {
    private let signalCache: SignalCache<SignalPostBody>
    let configuration: TelemetryManagerConfiguration

    private var sendTimerSource: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.telemetrydeck.SignalTimer", qos: .utility)

    /// Number of consecutive transmission failures.
    ///
    /// Read and written only on `timerQueue`.
    private var consecutiveFailures: Int = 0

    /// Number of completed send attempts (success + failure paths).
    ///
    /// Read and written only on `timerQueue`.
    private var sendCompletions: Int = 0

    #if DEBUG
        /// Test-only accessor for `consecutiveFailures`.
        ///
        /// Uses a synchronous hop onto `timerQueue` for safe reads.
        var consecutiveFailuresForTesting: Int {
            timerQueue.sync { consecutiveFailures }
        }

        /// Test-only accessor for `sendCompletions`.
        ///
        /// Uses a synchronous hop onto `timerQueue` for safe reads.
        var sendCompletionsForTesting: Int {
            timerQueue.sync { sendCompletions }
        }

        /// Test-only accessor to push signals directly into the cache.
        var signalCacheForTesting: SignalCache<SignalPostBody> { signalCache }

        var _shouldFailNextEncode: Bool = false
    #endif

    init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration

        // We automatically load any old signals from disk on initialisation
        signalCache = SignalCache(logHandler: configuration.swiftUIPreviewMode ? nil : configuration.logHandler, cacheLimit: configuration.cacheLimit)

        // Before the app terminates, we want to save any pending signals to disk
        // We need to monitor different notifications for different devices.
        // macOS - We can simply wait for the app to terminate at which point we get enough time to save the cache
        // which is then restored when the app is cold started and all init's fire.
        // iOS - App termination is an unreliable method to do work, so we use moving to background and foreground to save/load the cache.
        // watchOS and tvOS - We can only really monitor moving to background and foreground to save/load the cache.
        // watchOS pre7.0 - Doesn't have any kind of notification to monitor.
        #if os(macOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillTerminate),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        #elseif os(watchOS)
            if #available(watchOS 7.0, *) {
                // We need to use a delay with these type of notifications because they fire on app load which causes a double load of the cache from disk
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(self.didEnterForeground),
                        name: WKExtension.applicationWillEnterForegroundNotification,
                        object: nil
                    )
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(self.didEnterBackground),
                        name: WKExtension.applicationDidEnterBackgroundNotification,
                        object: nil
                    )
                }
            } else {
                // Pre watchOS 7.0, this library will not use disk caching at all as there are no notifications we can observe.
            }
        #elseif os(tvOS) || os(iOS) || os(visionOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // We need to use a delay with these type of notifications because they fire on app load which causes a double load of the cache from disk
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.didEnterForeground),
                    name: UIApplication.willEnterForegroundNotification,
                    object: nil
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.didEnterBackground),
                    name: UIApplication.didEnterBackgroundNotification,
                    object: nil
                )
            }
        #endif

        sendCachedSignalsRepeatedly()
    }

    /// Fires an immediate send attempt and then starts the self-rescheduling timer.
    private func sendCachedSignalsRepeatedly() {
        attemptToSendNextBatchOfCachedSignals()
        timerQueue.async {
            self.consecutiveFailures = 0
            self.scheduleNextTransmission()
        }
    }

    /// Cancels any pending timer and schedules the next one-shot transmission with exponential backoff.
    ///
    /// Must only be called from `timerQueue`.
    private func scheduleNextTransmission() {
        sendTimerSource?.cancel()

        let exponent = Double(consecutiveFailures)
        let delay = min(configuration.transmitInterval * pow(2, exponent), configuration.maxBackoffInterval)

        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(deadline: .now() + delay)
        source.setEventHandler { [weak self] in
            self?.attemptToSendNextBatchOfCachedSignals()
        }
        source.resume()
        sendTimerSource = source
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

                let payload =
                    defaultParameters
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
    @Sendable
    func attemptToSendNextBatchOfCachedSignals() {
        configuration.logHandler?.log(.debug, message: "Current signal cache count: \(signalCache.count())")

        let queuedSignals: [SignalPostBody] = signalCache.pop()
        guard !queuedSignals.isEmpty else {
            handleSendSuccess()
            return
        }

        configuration.logHandler?.log(message: "Sending \(queuedSignals.count) signals leaving a cache of \(signalCache.count()) signals")

        let body: Data
        do {
            body = try encodeBatch(queuedSignals)
        } catch {
            configuration.logHandler?.log(.error, message: "Failed to encode signal batch: \(error)")
            handleSendFailure(requeue: queuedSignals)
            return
        }

        send(body) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                self.configuration.logHandler?.log(.error, message: "\(error)")
                self.handleSendFailure(requeue: queuedSignals)
                return
            }

            let disposition = response?.disposition() ?? .retry
            switch disposition {
            case .success:
                if let data = data, let messageString = String(data: data, encoding: .utf8) {
                    self.configuration.logHandler?.log(.debug, message: messageString)
                }
                self.handleSendSuccess()
            case .drop(let reason):
                self.configuration.logHandler?.log(
                    .error,
                    message: "Dropping \(queuedSignals.count) signal(s): rejected by server \(reason)"
                )
                self.handleSendSuccess()
            case .retry:
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.configuration.logHandler?.log(.debug, message: "Failed to send events (status \(code)), will try again later")
                self.handleSendFailure(requeue: queuedSignals)
            }
        }
    }

    private func handleSendFailure(requeue: [SignalPostBody]) {
        signalCache.push(requeue)
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.sendCompletions += 1
            self.consecutiveFailures += 1
            self.scheduleNextTransmission()
        }
    }

    private func handleSendSuccess() {
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.sendCompletions += 1
            self.consecutiveFailures = 0
            self.scheduleNextTransmission()
        }
    }
}

// MARK: - Notifications

extension SignalManager {
    @MainActor
    @objc fileprivate func appWillTerminate() {
        configuration.logHandler?.log(.debug, message: #function)

        #if os(watchOS) || os(macOS)
            self.signalCache.backupCache()
        #else
            if TelemetryEnvironment.isAppExtension {
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

    #if os(watchOS) || os(tvOS) || os(iOS) || os(visionOS)
        @objc func didEnterForeground() {
            configuration.logHandler?.log(.debug, message: #function)
            signalCache.reloadFromDisk()
            sendCachedSignalsRepeatedly()
        }

        @MainActor
        @objc func didEnterBackground() {
            configuration.logHandler?.log(.debug, message: #function)

            sendTimerSource?.cancel()
            sendTimerSource = nil

            #if os(watchOS) || os(macOS)
                self.signalCache.backupCache()
            #else
                if TelemetryEnvironment.isAppExtension {
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

extension SignalManager {
    #if DEBUG
        internal var shouldFailNextEncodeForTesting: Bool {
            get { _shouldFailNextEncode }
            set { _shouldFailNextEncode = newValue }
        }
    #endif

    internal func encodeBatch(_ bodies: [SignalPostBody]) throws -> Data {
        #if DEBUG
            if _shouldFailNextEncode {
                _shouldFailNextEncode = false
                throw TelemetryError.encodeFailed(TelemetryError.invalidEndpointUrl)
            }
        #endif
        return try JSONEncoder.telemetryEncoder.encode(bodies)
    }

    private func send(_ body: Data, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard let url = SignalManager.getServiceUrl(baseURL: self.configuration.apiBaseURL, namespace: self.configuration.namespace) else {
                self.configuration.logHandler?.log(
                    .error,
                    message: "Unable to construct signal API URL for namespace \(self.configuration.namespace ?? "nil")"
                )
                DispatchQueue.main.async { completionHandler(nil, nil, TelemetryError.invalidEndpointUrl) }
                return
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body

            if let messageString = String(data: body, encoding: .utf8) {
                self.configuration.logHandler?.log(.debug, message: messageString)
            }

            let task = self.configuration.urlSession.dataTask(with: urlRequest, completionHandler: completionHandler)
            task.resume()
        }
    }

    static func getServiceUrl(baseURL: URL, namespace: String? = nil) -> URL? {
        var base = baseURL.absoluteString
        if !base.hasSuffix("/") {
            base += "/"
        }

        let suffix: String
        if let namespace, !namespace.isEmpty {
            suffix = "v2/namespace/\(namespace)/"
        } else {
            suffix = "v2/"
        }

        let serviceURL = URL(string: base + suffix)
        assert(serviceURL != nil, "Failed to construct service URL from base: \(baseURL)")
        return serviceURL
    }
}

// MARK: - Helpers

extension SignalManager {
    /// The default user identifier. If the platform supports it, the ``identifierForVendor``. Otherwise, a self-generated `UUID` which is persisted in custom `UserDefaults` if available.
    @MainActor
    var defaultUserIdentifier: String {
        guard configuration.defaultUser == nil else { return configuration.defaultUser! }

        #if os(iOS) || os(tvOS) || os(visionOS)
            return UIDevice.current.identifierForVendor?.uuidString
                ?? "unknown user \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
        #elseif os(watchOS)
            if #available(watchOS 6.2, *) {
                return WKInterfaceDevice.current().identifierForVendor?.uuidString
                    ?? "unknown user \(DefaultSignalPayload.systemVersion) \(DefaultSignalPayload.buildNumber)"
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

fileprivate enum ResponseDisposition {
    case success
    case drop(reason: String)
    case retry
}

extension URLResponse {
    fileprivate func disposition() -> ResponseDisposition {
        guard let httpResponse = self as? HTTPURLResponse else {
            return .retry
        }
        let code = httpResponse.statusCode
        if (200...299).contains(code) {
            return .success
        }
        switch code {
        case 400: return .drop(reason: "Bad Request (400)")
        case 401: return .drop(reason: "Unauthorized (401)")
        case 403: return .drop(reason: "Forbidden (403)")
        case 404: return .drop(reason: "Not Found (404)")
        case 413: return .drop(reason: "Payload Too Large (413)")
        case 422: return .drop(reason: "Unprocessable Entity (422)")
        case 501: return .drop(reason: "Not Implemented (501)")
        case 505: return .drop(reason: "HTTP Version Not Supported (505)")
        default: return .retry
        }
    }
}

// MARK: - Errors

private enum TelemetryError: Error {
    case invalidEndpointUrl
    case encodeFailed(Error)
}

extension TelemetryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidEndpointUrl:
            return "Invalid endpoint URL"
        case .encodeFailed(let error):
            return "Failed to encode signal batch: \(error)"
        }
    }
}
