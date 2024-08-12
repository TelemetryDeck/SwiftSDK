import Foundation

public struct LogHandler: Sendable {
    public enum LogLevel: Int, CustomStringConvertible, Sendable {
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
    }

    let logLevel: LogLevel
    let handler: @Sendable (LogLevel, String) -> Void

    public init(logLevel: LogHandler.LogLevel, handler: @escaping @Sendable (LogHandler.LogLevel, String) -> Void) {
        self.logLevel = logLevel
        self.handler = handler
    }

    internal func log(_ level: LogLevel = .info, message: String) {
        if level.rawValue >= logLevel.rawValue {
            handler(level, message)
        }
    }

    public static func stdout(_ logLevel: LogLevel) -> LogHandler {
        LogHandler(logLevel: logLevel) { level, message in
            print("[TelemetryDeck: \(level.description)] \(message)")
        }
    }
}
