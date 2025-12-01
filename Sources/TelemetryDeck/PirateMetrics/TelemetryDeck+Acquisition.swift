import Foundation

extension TelemetryDeck {
    /// Sends a telemetry signal indicating that a user was acquired through a specific channel.
    ///
    /// - Parameters:
    ///   - channel: The acquisition channel through which the user was acquired (e.g., "organic", "paid-search", "social-media").
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func acquiredUser(
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

    /// Sends a telemetry signal indicating that a lead has been initiated.
    ///
    /// - Parameters:
    ///   - leadID: A unique identifier for the lead being tracked.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func leadStarted(
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

    /// Sends a telemetry signal indicating that a lead has been successfully converted.
    ///
    /// - Parameters:
    ///   - leadID: A unique identifier for the lead that was converted. Should match the identifier used in `leadStarted`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func leadConverted(
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
