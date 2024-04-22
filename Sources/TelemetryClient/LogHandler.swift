import Foundation
import OSLog

public struct LogHandler {
    public enum LogLevel: Int, CustomStringConvertible {
        case debug = 0
        case info = 1
        case error = 2

        public var description: String {
            switch self {
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .error:
                return "ERROR"
            }
        }

        public var osLogLevel: OSLogType {
            switch self {
            case .debug: 
                return OSLogType.debug
            case .info:
                return OSLogType.info
            case .error:
                return OSLogType.error
            }
        }
    }

    let logLevel: LogLevel
    let handler: (LogLevel, String) -> Void

    public init(logLevel: LogHandler.LogLevel, handler: @escaping (LogHandler.LogLevel, String) -> Void) {
        self.logLevel = logLevel
        self.handler = handler
    }

    internal func log(_ level: LogLevel = .info, message: String) {
        if level.rawValue >= logLevel.rawValue {
            handler(level, message)
        }
    }

    @available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *)
    public static var oslog = { logLevel in
        LogHandler(logLevel: logLevel) { level, message in
            Logger(
                subsystem: "TelemetryDeck",
                category: "LogHandler"
            ).log(level: logLevel.osLogLevel, "\(message, privacy: .public)")
        }
    }

    public static var stdout = { logLevel in
        LogHandler(logLevel: logLevel) { level, message in
            print("[TelemetryDeck: \(level.description)] \(message)")
        }
    }
}
