import Foundation

/// A sink for SDK log messages.
public protocol Logging: Sendable {
    func log(_ level: LogLevel, _ message: @autoclosure () -> String)
}

/// The severity level of a log message.
public enum LogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info = 1
    case error = 2

    /// Compares two log levels by their raw integer severity.
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
