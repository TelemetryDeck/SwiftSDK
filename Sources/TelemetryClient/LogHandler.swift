import Foundation

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
    }
    
    let logLevel: LogLevel
    let handler: (LogLevel, String) -> Void
    
    internal func log(_ level: LogLevel = .info, message: String) {
        if level.rawValue >= logLevel.rawValue {
            handler(level, message)
        }
    }
    
    public static var stdout = { logLevel in
        LogHandler(logLevel: logLevel) { level, message in
            print("[TelemetryDeck: \(level.description)] \(message)")
        }
    }
}
