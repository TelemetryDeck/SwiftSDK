import CommonCrypto
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#elseif os(tvOS)
import TVUIKit
#endif

internal class SignalManager {
    private let minimumWaitTimeBetweenRequests: Double = 10 // seconds
    
    private var signalCache: SignalCache<SignalPostBody>
    let configuration: TelemetryManagerConfiguration
    private var sendTimer: Timer?
    
    init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration
        
        // We automatically load any old signals from disk on initialisation
        signalCache = SignalCache(showDebugLogs: configuration.showDebugLogs)
        
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
        #elseif os(tvOS) || os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // We need to use a delay with these type of notifications because they fire on app load which causes a double load of the cache from disk
            NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        #endif
        
        startTimer()
    }
    
    /// Setup a timer to send the Signals
    private func startTimer() {
        sendTimer?.invalidate()
        
        sendTimer = Timer.scheduledTimer(timeInterval: minimumWaitTimeBetweenRequests, target: self, selector: #selector(checkForSignalsAndSend), userInfo: nil, repeats: true)
        
        // Fire the timer to attempt to send any cached Signals from a previous session
        checkForSignalsAndSend()
    }
    
    /// Adds a signal to the process queue
    func processSignal(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:], configuration: TelemetryManagerConfiguration) {
        DispatchQueue.global(qos: .utility).async { [self] in

            let payLoad = SignalPayload(additionalPayload: additionalPayload)
            
            let signalPostBody = SignalPostBody(
                receivedAt: Date(),
                appID: UUID(uuidString: configuration.telemetryAppID)!,
                clientUser: sha256(str: clientUser ?? defaultUserIdentifier),
                sessionID: configuration.sessionID.uuidString,
                type: "\(signalType)",
                payload: payLoad.toMultiValueDimension(),
                isTestMode: configuration.testMode ? "true" : "false"
            )
            
            if configuration.showDebugLogs {
                print("Process signal: \(signalPostBody)")
            }
            
            signalCache.push(signalPostBody)
        }
    }
    
    /// Send signals once we have more than the minimum.
    /// If any fail to send, we put them back into the cache to send later.
    @objc
    private func checkForSignalsAndSend() {
        if configuration.showDebugLogs {
            print("Current signal cache count: \(signalCache.count())")
        }
        
        let queuedSignals: [SignalPostBody] = signalCache.pop()
        if !queuedSignals.isEmpty {
            if configuration.showDebugLogs {
                print("Sending \(queuedSignals.count) signals leaving a cache of \(signalCache.count()) signals")
            }
            send(queuedSignals) { [unowned self] data, response, error in
                
                if let error = error {
                    if configuration.showDebugLogs {
                        print(error)
                    }
                    // The send failed, put the signal back into the queue
                    self.signalCache.push(queuedSignals)
                    return
                }
                
                // Check for valid status code response
                guard response?.statusCodeError() == nil else {
                    let statusError = response!.statusCodeError()!
                    if configuration.showDebugLogs {
                        print(statusError)
                    }
                    // The send failed, put the signal back into the queue
                    self.signalCache.push(queuedSignals)
                    return
                }
                
                if let data = data {
                    if configuration.showDebugLogs {
                        print(String(data: data, encoding: .utf8)!)
                    }
                }
            }
        }
    }
}

// MARK: - Notifications

private extension SignalManager {
    @objc func appWillTerminate() {
        if configuration.showDebugLogs {
            print(#function)
        }
        
        signalCache.backupCache()
    }
    
    /// WatchOS doesn't have a notification before it's killed, so we have to use background/foreground
    /// This means our `init()` above doesn't always run when coming back to foreground, so we have to manually
    /// reload the cache. This also means we miss any signals sent during watchDidEnterForeground
    /// so we merge them into the new cache.
    #if os(watchOS) || os(tvOS) || os(iOS)
    @objc func didEnterForeground() {
        if configuration.showDebugLogs {
            print(#function)
        }
        
        let currentCache = signalCache.pop()
        if configuration.showDebugLogs {
            print("current cache is \(currentCache.count) signals")
        }
        signalCache = SignalCache(showDebugLogs: configuration.showDebugLogs)
        signalCache.push(currentCache)
        
        startTimer()
    }
    
    @objc func didEnterBackground() {
        if configuration.showDebugLogs {
            print(#function)
        }
        
        sendTimer?.invalidate()
        sendTimer = nil
        
        signalCache.backupCache()
    }
    #endif
}

// MARK: - Comms

private extension SignalManager {
    private func send(_ signalPostBodies: [SignalPostBody], completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [self] in
            let path = "/api/v1/apps/\(configuration.telemetryAppID)/signals/multiple/"
            let url = configuration.apiBaseURL.appendingPathComponent(path)

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

            urlRequest.httpBody = try! JSONEncoder.telemetryEncoder.encode(signalPostBodies)
            if configuration.showDebugLogs {
                print(String(data: urlRequest.httpBody!, encoding: .utf8)!)
            }
            
            let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: completionHandler)
            task.resume()
        }
    }
}

// MARK: - Helpers

private extension SignalManager {
    /// The default user identifier. If the platform supports it, the identifierForVendor. Otherwise, system version
    /// and build number (in which case it's strongly recommended to supply an email or UUID or similar identifier for
    /// your user yourself.
    var defaultUserIdentifier: String {
        guard configuration.defaultUser == nil else { return configuration.defaultUser! }
        
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown user \(SignalPayload.systemVersion) \(SignalPayload.buildNumber)"
        #elseif os(watchOS)
        if #available(watchOS 6.2, *) {
            return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown user \(SignalPayload.systemVersion) \(SignalPayload.buildNumber)"
        } else {
            return "unknown user \(SignalPayload.platform) \(SignalPayload.systemVersion) \(SignalPayload.buildNumber)"
        }
        #else
        #if DEBUG
        print("[Telemetry] On this platform, Telemetry can't generate a unique user identifier. It is recommended you supply one yourself. More info: https://telemetrydeck.com/pages/signal-reference.html")
        #endif
        return "unknown user \(SignalPayload.platform) \(SignalPayload.systemVersion) \(SignalPayload.buildNumber)"
        #endif
    }
    
    /**
     * Example SHA 256 Hash using CommonCrypto
     * CC_SHA256 API exposed from from CommonCrypto-60118.50.1:
     * https://opensource.apple.com/source/CommonCrypto/CommonCrypto-60118.50.1/include/CommonDigest.h.auto.html
     **/
    func sha256(str: String) -> String {
        if let strData = str.data(using: String.Encoding.utf8) {
            /// #define CC_SHA256_DIGEST_LENGTH     32
            /// Creates an array of unsigned 8 bit integers that contains 32 zeros
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

            /// CC_SHA256 performs digest calculation and places the result in the caller-supplied buffer for digest (md)
            /// Takes the strData referenced value (const unsigned char *d) and hashes it into a reference to the digest parameter.
            _ = strData.withUnsafeBytes {
                // CommonCrypto
                // extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)  -|
                // OpenSSL                                                                             |
                // unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md)        <-|
                CC_SHA256($0.baseAddress, UInt32(strData.count), &digest)
            }

            var sha256String = ""
            /// Unpack each byte in the digest array and add them to the sha256String
            for byte in digest {
                sha256String += String(format: "%02x", UInt8(byte))
            }

            return sha256String
        }
        return ""
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
                return TelemetryError.Unauthorised
            } else if statusCode() == 403 {
                return TelemetryError.Forbidden
            } else if statusCode() == 413 {
                return TelemetryError.PayloadTooLarge
            } else {
                return TelemetryError.InvalidStatusCode(statusCode: statusCode() ?? 0)
            }
        }
        return nil
    }
}

// MARK: - Errors

private enum TelemetryError: Error {
    case Unauthorised
    case Forbidden
    case PayloadTooLarge
    case InvalidStatusCode(statusCode: Int)
}

extension TelemetryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .InvalidStatusCode(let statusCode):
            return "Invalid status code \(statusCode)"
        case .Unauthorised:
            return "Unauthorized (401)"
        case .Forbidden:
            return "Forbidden (403)"
        case .PayloadTooLarge:
            return "Payload is too large (413)"
        }
    }
}
