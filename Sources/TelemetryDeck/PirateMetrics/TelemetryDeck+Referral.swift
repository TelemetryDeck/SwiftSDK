import Foundation

extension TelemetryDeck {
    private static func referralSent(
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

    private static func userRatingSubmitted(
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
