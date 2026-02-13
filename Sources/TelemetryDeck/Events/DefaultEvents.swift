import Foundation

/// Typed event name constants for SDK-emitted events.
public enum DefaultEvents {
    /// Session lifecycle events.
    public enum Session: String {
        case started = "TelemetryDeck.Session.started"
    }

    /// Navigation tracking events.
    public enum Navigation: String {
        case pathChanged = "TelemetryDeck.Navigation.pathChanged"
    }

    /// Acquisition funnel events.
    public enum Acquisition: String {
        case userAcquired = "TelemetryDeck.Acquisition.userAcquired"
        case leadStarted = "TelemetryDeck.Acquisition.leadStarted"
        case leadConverted = "TelemetryDeck.Acquisition.leadConverted"
        case newInstallDetected = "TelemetryDeck.Acquisition.newInstallDetected"
    }

    /// Activation funnel events.
    public enum Activation: String {
        case onboardingCompleted = "TelemetryDeck.Activation.onboardingCompleted"
        case coreFeatureUsed = "TelemetryDeck.Activation.coreFeatureUsed"
    }

    /// Referral and rating events.
    public enum Referral: String {
        case sent = "TelemetryDeck.Referral.sent"
        case userRatingSubmitted = "TelemetryDeck.Referral.userRatingSubmitted"
    }

    /// Revenue-related events.
    public enum Revenue: String {
        case paywallShown = "TelemetryDeck.Revenue.paywallShown"
    }

    /// In-app purchase events.
    public enum Purchase: String {
        case completed = "TelemetryDeck.Purchase.completed"
        case freeTrialStarted = "TelemetryDeck.Purchase.freeTrialStarted"
        case convertedFromTrial = "TelemetryDeck.Purchase.convertedFromTrial"
    }

    /// Error reporting events.
    public enum Error: String {
        case occurred = "TelemetryDeck.Error.occurred"
    }
}
