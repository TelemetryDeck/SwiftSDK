import Foundation

#if canImport(OSLog)
    import OSLog
#endif

/// Forwards SDK log messages to `os.Logger` where available, or `print` as a fallback.
public struct DefaultLogger: Logging {
    private let minimumLevel: LogLevel

    /// Creates a logger that filters messages below the given minimum level.
    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }

    /// Logs the message at the given level if it meets the minimum level threshold.
    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        guard level >= minimumLevel else { return }

        let messageText = message()

        #if canImport(OSLog)
            if #available(iOS 14, macCatalyst 14, *) {
                let osLog = os.Logger(subsystem: "TelemetryDeck", category: "SDK")
                switch level {
                case .debug: osLog.debug("\(messageText)")
                case .info: osLog.info("\(messageText)")
                case .error: osLog.error("\(messageText)")
                }
            } else {
                print("[TelemetryDeck] \(messageText)")
            }
        #else
            print("[TelemetryDeck] \(messageText)")
        #endif
    }
}
