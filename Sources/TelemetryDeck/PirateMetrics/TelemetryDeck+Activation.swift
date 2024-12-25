import Foundation

extension TelemetryDeck {
    static func onboardingCompleted(
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

    static func coreFeatureUsed(
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
