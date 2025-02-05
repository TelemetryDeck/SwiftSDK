import Foundation

extension TelemetryDeck {
    private static func acquiredUser(
        channel: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let acquisitionParameters = ["TelemetryDeck.Acquisition.channel": channel]

        self.internalSignal(
            "TelemetryDeck.Acquisition.userAcquired",
            parameters: acquisitionParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }

    private static func leadStarted(
        leadID: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let leadParameters: [String: String] = ["TelemetryDeck.Acquisition.leadID": leadID]

        self.internalSignal(
            "TelemetryDeck.Acquisition.leadStarted",
            parameters: leadParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }

    private static func leadConverted(
        leadID: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        let leadParameters: [String: String] = ["TelemetryDeck.Acquisition.leadID": leadID]

        self.internalSignal(
            "TelemetryDeck.Acquisition.leadConverted",
            parameters: leadParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }
}
