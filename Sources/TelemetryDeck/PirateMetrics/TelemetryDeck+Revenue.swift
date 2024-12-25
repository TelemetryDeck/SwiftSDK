import Foundation

extension TelemetryDeck {
    // TODO: add documentation comment with common/recommended usage examples
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
