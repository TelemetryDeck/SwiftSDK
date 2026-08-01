import Foundation

/// An error thrown by the TelemetryDeck SDK.
public struct TelemetryDeckError: Error, LocalizedError, CustomDebugStringConvertible, CustomNSError, Sendable {
    /// Identifies the category of error.
    public enum Code: Int, Sendable {
        case invalidConfiguration = 1001
    }

    /// The specific error code.
    public let code: Code
    private let _localizedDescription: String

    init(code: Code, localizedDescription: String) {
        self.code = code
        self._localizedDescription = localizedDescription
    }

    /// A localised, human-readable description of the error.
    public var errorDescription: String? {
        _localizedDescription
    }

    /// A debug description including the error code and message.
    public var debugDescription: String {
        "TelemetryDeckError.\(code) (\(code.rawValue)): \(_localizedDescription)"
    }

    /// The NSError domain for TelemetryDeck errors.
    public static var errorDomain: String {
        "TelemetryDeck"
    }

    /// The integer error code used when bridging to NSError.
    public var errorCode: Int {
        code.rawValue
    }

    /// The NSError user info dictionary.
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: _localizedDescription]
    }

}

extension TelemetryDeckError.Code {
    /// Allows using a `Code` value in a `catch` pattern to match a thrown `TelemetryDeckError`.
    public static func ~= <E: Error>(match: Self, error: E) -> Bool {
        guard let telemetryError = error as? TelemetryDeckError else { return false }
        return telemetryError.code == match
    }
}
