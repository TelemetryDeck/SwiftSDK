import Foundation

/// A generic wrapper that conforms any error to ``IdentifiableError``, exposing its `localizedDescription` as the `message`.
public struct AnyIdentifiableError: LocalizedError, IdentifiableError {
    /// Unique identifier for the error, such as `TelemetryDeck.Session.started`.
    public let id: String

    /// The underlying error being wrapped.
    public let error: any Error

    /// Initializes with a given `id` and `error`.
    /// - Parameters:
    ///   - id: Unique identifier for the error, such as `TelemetryDeck.Session.started`.
    ///   - error: The error to be wrapped.
    public init(id: String, error: any Error) {
        self.id = id
        self.error = error
    }

    /// Provides the localized description of the wrapped error.
    public var errorDescription: String {
        self.error.localizedDescription
    }
}

extension Error {
    /// Wraps any caught error with an `id` for use with ``TelemetryDeck.signal(identifiableError:)``.
    /// - Parameters:
    ///   - id: Unique identifier for the error, such as `TelemetryDeck.Session.started`.
    /// - Returns: An ``AnyIdentifiableError`` instance wrapping the given error.
    public func with(id: String) -> AnyIdentifiableError {
        AnyIdentifiableError(id: id, error: self)
    }
}
