import Foundation

extension TelemetryDeck {
    /// Sends a telemetry signal indicating that a referral has been sent.
    ///
    /// - Parameters:
    ///   - receiversCount: The number of recipients who received the referral. Default is `1`.
    ///   - kind: An optional categorization of the referral type (e.g., "email", "social", "sms"). Default is `nil`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func referralSent(
        receiversCount: Int = 1,
        kind: String? = nil,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        var referralParameters = ["TelemetryDeck.Referral.receiversCount": String(receiversCount)]

        if let kind {
            referralParameters["TelemetryDeck.Referral.kind"] = kind
        }

        self.internalSignal(
            "TelemetryDeck.Referral.sent",
            parameters: referralParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }

    /// Sends a telemetry signal indicating that a user has submitted a rating.
    ///
    /// - Parameters:
    ///   - rating: The rating value submitted by the user. Must be between 0 and 10 inclusive.
    ///   - comment: An optional comment or feedback text accompanying the rating. Default is `nil`.
    ///   - parameters: Additional parameters to include with the signal. Default is an empty dictionary.
    ///   - customUserID: An optional custom user identifier. If provided, it overrides the default user identifier from the configuration. Default is `nil`.
    public static func userRatingSubmitted(
        rating: Int,
        comment: String? = nil,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        guard (0...10).contains(rating) else {
            TelemetryManager.shared.configuration.logHandler?.log(.error, message: "Rating must be between 0 and 10")
            return
        }

        var ratingParameters = [
            "TelemetryDeck.Referral.ratingValue": String(rating)
        ]

        if let comment {
            ratingParameters["TelemetryDeck.Referral.ratingComment"] = comment
        }

        self.internalSignal(
            "TelemetryDeck.Referral.userRatingSubmitted",
            parameters: ratingParameters.merging(parameters) { $1 },
            customUserID: customUserID
        )
    }
}
