import Foundation
import SwiftUI

// MARK: - Errors

extension TelemetryDeck {
    /// Sends an error event with the given identifier, optional category, message, and additional parameters.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.errorOccurred(id:category:message:parameters:floatValue:customUserID:)' instead")
    public static func errorOccurred(
        id: String,
        category: ErrorCategory? = nil,
        message: String? = nil,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        Task {
            await errorOccurred(
                id: id,
                category: category,
                message: message,
                parameters: EventParameters(parameters),
                floatValue: floatValue,
                customUserID: customUserID
            )
        }
    }

    /// Sends an error event for the given `IdentifiableError`, using its localised description as the message.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.errorOccurred(identifiableError:category:parameters:)' instead")
    public static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        Task {
            await errorOccurred(
                identifiableError: identifiableError,
                category: category,
                parameters: EventParameters(parameters),
                floatValue: floatValue,
                customUserID: customUserID
            )
        }
    }

    /// Sends an error event for the given `IdentifiableError` with an explicit optional message override.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use 'await TelemetryDeck.errorOccurred(identifiableError:category:message:parameters:)' instead")
    public static func errorOccurred(
        identifiableError: IdentifiableError,
        category: ErrorCategory = .thrownException,
        message: String? = nil,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        Task {
            await errorOccurred(
                identifiableError: identifiableError,
                category: category,
                message: message,
                parameters: EventParameters(parameters),
                floatValue: floatValue,
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Acquisition

extension TelemetryDeck {
    /// Sends an acquisition event recording the channel through which this user was acquired.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.acquiredUser(channel:parameters:customUserID:)' instead")
    public static func acquiredUser(
        channel: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await acquiredUser(
                channel: channel,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }

    /// Sends an event indicating that a lead funnel has started for the given lead identifier.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.leadStarted(leadID:parameters:customUserID:)' instead")
    public static func leadStarted(
        leadID: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await leadStarted(
                leadID: leadID,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }

    /// Sends an event indicating that a lead has converted for the given lead identifier.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.leadConverted(leadID:parameters:customUserID:)' instead")
    public static func leadConverted(
        leadID: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await leadConverted(
                leadID: leadID,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Activation

extension TelemetryDeck {
    /// Sends an event indicating that the user has completed onboarding.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.onboardingCompleted(parameters:customUserID:)' instead")
    public static func onboardingCompleted(
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await onboardingCompleted(
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }

    /// Sends an event indicating that the user engaged with a core feature.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.coreFeatureUsed(featureName:parameters:customUserID:)' instead")
    public static func coreFeatureUsed(
        featureName: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await coreFeatureUsed(
                featureName: featureName,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Referral

extension TelemetryDeck {
    /// Sends an event recording that the user sent a referral to one or more recipients.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.referralSent(receiversCount:kind:parameters:customUserID:)' instead")
    public static func referralSent(
        receiversCount: Int = 1,
        kind: String? = nil,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await referralSent(
                receiversCount: receiversCount,
                kind: kind,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }

    /// Sends an event recording a user-submitted rating (0–10) and optional comment.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.userRatingSubmitted(rating:comment:parameters:customUserID:)' instead")
    public static func userRatingSubmitted(
        rating: Int,
        comment: String? = nil,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await userRatingSubmitted(
                rating: rating,
                comment: comment,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Revenue

extension TelemetryDeck {
    /// Sends an event indicating that a paywall was shown to the user, including the reason it appeared.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.paywallShown(reason:parameters:customUserID:)' instead")
    public static func paywallShown(
        reason: String,
        parameters: [String: String] = [:],
        customUserID: String? = nil
    ) {
        Task {
            await paywallShown(
                reason: reason,
                parameters: EventParameters(parameters),
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Navigation

extension TelemetryDeck {
    /// Sends a navigation event recording a transition from `source` to `destination`.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.navigationPathChanged(from:to:customUserID:)' instead")
    public static func navigationPathChanged(
        from source: String,
        to destination: String,
        customUserID: String? = nil
    ) {
        Task {
            await navigationPathChanged(
                from: source,
                to: destination,
                customUserID: customUserID
            )
        }
    }

    /// Sends a navigation event to `destination`, using the last recorded path as the source.
    @available(*, deprecated, message: "Use 'await TelemetryDeck.navigationPathChanged(to:customUserID:)' instead")
    public static func navigationPathChanged(
        to destination: String,
        customUserID: String? = nil
    ) {
        Task {
            await navigationPathChanged(
                to: destination,
                customUserID: customUserID
            )
        }
    }
}

// MARK: - Duration Tracking

extension TelemetryDeck {
    /// Starts tracking a duration event with the given name.
    @available(*, deprecated, renamed: "startDurationEvent")
    public static func startDurationSignal(
        _ signalName: String,
        parameters: [String: String] = [:],
        includeBackgroundTime: Bool = false
    ) {
        Task {
            await startDurationEvent(
                signalName,
                parameters: EventParameters(parameters),
                includeBackgroundTime: includeBackgroundTime
            )
        }
    }

    /// Stops tracking a duration event and sends the resulting signal.
    @available(*, deprecated, renamed: "stopAndSendDurationEvent")
    public static func stopAndSendDurationSignal(
        _ signalName: String,
        parameters: [String: String] = [:],
        floatValue _: Double? = nil,
        customUserID _: String? = nil
    ) {
        Task {
            await stopAndSendDurationEvent(
                signalName,
                parameters: EventParameters(parameters)
            )
        }
    }

    /// Cancels an in-progress duration event without sending a signal.
    @available(*, deprecated, renamed: "cancelDurationEvent")
    public static func cancelDurationSignal(_ signalName: String) {
        Task {
            await cancelDurationEvent(signalName)
        }
    }
}

// MARK: - Purchases

#if canImport(StoreKit)
    import StoreKit

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    extension TelemetryDeck {
        /// Sends a purchase event for the given StoreKit transaction, automatically handling free trials.
        @available(*, deprecated, message: "Use 'await TelemetryDeck.purchaseCompleted(transaction:parameters:customUserID:)' instead")
        public static func purchaseCompleted(
            transaction: StoreKit.Transaction,
            parameters: [String: String] = [:],
            customUserID: String? = nil
        ) {
            Task {
                await purchaseCompleted(
                    transaction: transaction,
                    parameters: EventParameters(parameters),
                    customUserID: customUserID
                )
            }
        }
    }
#endif
