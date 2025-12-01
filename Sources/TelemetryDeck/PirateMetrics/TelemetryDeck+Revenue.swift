import Foundation

extension TelemetryDeck {
    /// Sends a telemetry signal indicating that a paywall has been shown to the user.
    ///
    /// - Parameters:
    ///   - reason: The reason or context for showing the paywall (e.g., "trial-expired", "feature-locked", "onboarding").
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func paywallShown(
        reason: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let paywallParameters = ["TelemetryDeck.Revenue.paywallShowReason": reason]

        self.internalSignal(
            "TelemetryDeck.Revenue.paywallShown",
            parameters: paywallParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }
}
