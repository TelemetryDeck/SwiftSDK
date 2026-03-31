import Foundation

/// Classifies the nature of an error for TelemetryDeck reporting.
public enum ErrorCategory: String, Sendable {
    case thrownException = "thrown-exception"
    case userInput = "user-input"
    case appState = "app-state"
}

/// An error that carries a stable, developer-assigned identifier for TelemetryDeck tracking.
public protocol IdentifiableError: Error {
    /// A stable identifier used to group occurrences of this error in the dashboard.
    var id: String { get }
}

/// Wraps any error with a developer-provided identifier, conforming to `IdentifiableError`.
public struct AnyIdentifiableError: LocalizedError, IdentifiableError {
    /// The stable identifier assigned to this error.
    public let id: String
    /// The underlying error being wrapped.
    public let error: any Error

    /// Creates a wrapper that associates the given identifier with the given error.
    public init(id: String, error: any Error) {
        self.id = id
        self.error = error
    }

    /// The localised description of the underlying error.
    public var errorDescription: String {
        self.error.localizedDescription
    }
}

extension Error {
    /// Wraps this error with a stable identifier for TelemetryDeck reporting.
    public func with(id: String) -> AnyIdentifiableError {
        AnyIdentifiableError(id: id, error: self)
    }
}

extension TelemetryDeck {
    /// Sends an error event with the given identifier, optional category, message, and additional parameters.
    public static func errorOccurred(
        id: String,
        category: ErrorCategory? = nil,
        message: String? = nil,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async {
        var errorParameters: EventParameters = [DefaultParams.Error.id.rawValue: id]

        if let category {
            errorParameters[DefaultParams.Error.category] = category.rawValue
        }

        if let message {
            errorParameters[DefaultParams.Error.message] = message
        }

        errorParameters.merge(parameters)

        await sdkEvent(
            DefaultEvents.Error.occurred,
            parameters: errorParameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
    }

    /// Sends an error event for the given `IdentifiableError`, using its localised description as the message.
    public static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async {
        await errorOccurred(
            id: identifiableError.id,
            category: category,
            message: identifiableError.localizedDescription,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
    }

    /// Sends an error event for the given `IdentifiableError` with an explicit optional message override.
    @_disfavoredOverload
    public static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        message: String? = nil,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async {
        await errorOccurred(
            id: identifiableError.id,
            category: category,
            message: message,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
    }
}
