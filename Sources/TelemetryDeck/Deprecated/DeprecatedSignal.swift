import Foundation

extension TelemetryDeck {
    /// Sends a signal with the given name and optional parameters.
    @available(*, deprecated, renamed: "event")
    public static func signal(
        _ signalName: String,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        event(
            signalName,
            parameters: EventParameters(parameters),
            floatValue: floatValue,
            customUserID: customUserID
        )
    }
}
