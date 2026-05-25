import Foundation

// MARK: - Acquisition

extension TelemetryDeck {
    /// Sends an acquisition event recording the channel through which this user was acquired.
    public static func acquiredUser(
        channel: String,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Acquisition.channel.rawValue: channel]
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Acquisition.userAcquired, parameters: params, customUserID: customUserID)
    }

    /// Sends an event indicating that a lead funnel has started for the given lead identifier.
    public static func leadStarted(
        leadID: String,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Acquisition.leadID.rawValue: leadID]
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Acquisition.leadStarted, parameters: params, customUserID: customUserID)
    }

    /// Sends an event indicating that a lead has converted for the given lead identifier.
    public static func leadConverted(
        leadID: String,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Acquisition.leadID.rawValue: leadID]
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Acquisition.leadConverted, parameters: params, customUserID: customUserID)
    }
}

// MARK: - Activation

extension TelemetryDeck {
    /// Sends an event indicating that the user has completed onboarding.
    public static func onboardingCompleted(
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        await sdkEvent(DefaultEvents.Activation.onboardingCompleted, parameters: parameters, customUserID: customUserID)
    }

    /// Sends an event indicating that the user engaged with a core feature.
    public static func coreFeatureUsed(
        featureName: String,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Activation.featureName.rawValue: featureName]
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Activation.coreFeatureUsed, parameters: params, customUserID: customUserID)
    }
}

// MARK: - Referral

extension TelemetryDeck {
    /// Sends an event recording that the user sent a referral to one or more recipients.
    public static func referralSent(
        receiversCount: Int,
        kind: String? = nil,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Referral.receiversCount.rawValue: receiversCount]
        if let kind {
            params[DefaultParams.Referral.kind] = kind
        }
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Referral.sent, parameters: params, customUserID: customUserID)
    }

    /// Sends an event recording a user-submitted rating (0–10) and optional comment.
    public static func userRatingSubmitted(
        rating: Int,
        comment: String? = nil,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        guard (0...10).contains(rating) else {
            await log(.error, "Rating must be between 0 and 10, got \(rating)")
            return
        }
        var params: EventParameters = [DefaultParams.Referral.ratingValue.rawValue: rating]
        if let comment {
            params[DefaultParams.Referral.ratingComment] = comment
        }
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Referral.userRatingSubmitted, parameters: params, customUserID: customUserID)
    }
}

// MARK: - Revenue

extension TelemetryDeck {
    /// Sends an event indicating that a paywall was shown to the user, including the reason it appeared.
    public static func paywallShown(
        reason: String,
        parameters: EventParameters = [:],
        customUserID: String? = nil
    ) async {
        var params: EventParameters = [DefaultParams.Revenue.paywallShowReason.rawValue: reason]
        params.merge(parameters)
        await sdkEvent(DefaultEvents.Revenue.paywallShown, parameters: params, customUserID: customUserID)
    }
}
