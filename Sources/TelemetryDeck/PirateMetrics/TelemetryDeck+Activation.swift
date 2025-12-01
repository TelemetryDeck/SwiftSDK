import Foundation

extension TelemetryDeck {
    /// Sends a telemetry signal indicating that a user has completed the onboarding process.
    ///
    /// - Parameters:
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func onboardingCompleted(
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let onboardingParameters: [String: String] = [:]

        self.internalSignal(
            "TelemetryDeck.Activation.onboardingCompleted",
            parameters: onboardingParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }

    /// Sends a telemetry signal indicating that a core feature of the application has been used.
    ///
    /// - Parameters:
    ///   - featureName: The name of the core feature that was used.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func coreFeatureUsed(
        featureName: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let featureParameters = [
            "TelemetryDeck.Activation.featureName": featureName
        ]

        self.internalSignal(
            "TelemetryDeck.Activation.coreFeatureUsed",
            parameters: featureParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }
}
