import Foundation

public extension TelemetryDeck {
    /// Sends a telemetry signal indicating that an error has occurred.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the error.
    ///   - category: An optional category for the error. Default is `nil`.
    ///   - message: An optional message describing the error. Default is `nil`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - floatValue: An optional floating-point value to include with the signal. Default is `nil`.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    static func errorOccurred(
        id: String,
        category: ErrorCategory? = nil,
        message: String? = nil,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        var errorParameters: [String: String] = ["TelemetryDeck.Error.id": id]

        if let category {
            errorParameters["TelemetryDeck.Error.category"] = category.rawValue
        }

        if let message {
            errorParameters["TelemetryDeck.Error.message"] = message
        }

        self.internalSignal(
            "TelemetryDeck.Error.occurred",
            parameters: errorParameters.merging(parameters) { $1 },
            floatValue: floatValue,
            customUserID: customUserID
        )
    }

    /// Sends a telemetry signal indicating that an identifiable error has occurred.
    ///
    /// - Parameters:
    ///   - identifiableError: The error that conforms to `IdentifiableError`. Conform any error type by calling `.with(id:)` on it.
    ///   - category: The category of the error. Default is `.thrownException`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - floatValue: An optional floating-point value to include with the signal. Default is `nil`.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        self.errorOccurred(
            id: identifiableError.id,
            category: category,
            message: identifiableError.localizedDescription,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
    }

    /// Sends a telemetry signal indicating that an identifiable error has occurred, with an optional message.
    ///
    /// - Parameters:
    ///   - identifiableError: The error that conforms to `IdentifiableError`.
    ///   - category: The category of the error. Default is `.thrownException`.
    ///   - message: An optional message describing the error. Default is `nil`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - floatValue: An optional floating-point value to include with the signal. Default is `nil`.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    ///
    ///  - Note: Use this overload if you want to provide a custom `message` parameter. Prefer ``errorOccurred(identifiableError:category:parameters:floatValue:customUserID:)`` to send
    ///    `error.localizedDescription` as the `message` automatically.
    @_disfavoredOverload
    static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        message: String? = nil,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        self.errorOccurred(
            id: identifiableError.id,
            category: category,
            message: message,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
    }
}
