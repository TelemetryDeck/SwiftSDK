import Foundation

/// Typed parameter key constants for SDK-enriched event parameters.
public enum DefaultParams {
    /// Device hardware and operating system parameters.
    public enum Device: String {
        case platform = "TelemetryDeck.Device.platform"
        case operatingSystem = "TelemetryDeck.Device.operatingSystem"
        case systemVersion = "TelemetryDeck.Device.systemVersion"
        case systemMajorVersion = "TelemetryDeck.Device.systemMajorVersion"
        case systemMajorMinorVersion = "TelemetryDeck.Device.systemMajorMinorVersion"
        case modelName = "TelemetryDeck.Device.modelName"
        case architecture = "TelemetryDeck.Device.architecture"
        case timeZone = "TelemetryDeck.Device.timeZone"
        case orientation = "TelemetryDeck.Device.orientation"
        case screenResolutionWidth = "TelemetryDeck.Device.screenResolutionWidth"
        case screenResolutionHeight = "TelemetryDeck.Device.screenResolutionHeight"
        case screenScaleFactor = "TelemetryDeck.Device.screenScaleFactor"
    }

    /// Parameters describing the current run environment (simulator, debug, TestFlight, App Store).
    public enum RunContext: String {
        case isSimulator = "TelemetryDeck.RunContext.isSimulator"
        case isDebug = "TelemetryDeck.RunContext.isDebug"
        case isTestFlight = "TelemetryDeck.RunContext.isTestFlight"
        case isAppStore = "TelemetryDeck.RunContext.isAppStore"
        case targetEnvironment = "TelemetryDeck.RunContext.targetEnvironment"
        case locale = "TelemetryDeck.RunContext.locale"
        case language = "TelemetryDeck.RunContext.language"
        case extensionIdentifier = "TelemetryDeck.RunContext.extensionIdentifier"
    }

    /// App version and build number parameters.
    public enum AppInfo: String {
        case version = "TelemetryDeck.AppInfo.version"
        case buildNumber = "TelemetryDeck.AppInfo.buildNumber"
        case versionAndBuildNumber = "TelemetryDeck.AppInfo.versionAndBuildNumber"
    }

    /// SDK name and version parameters.
    public enum SDK: String {
        case name = "TelemetryDeck.SDK.name"
        case version = "TelemetryDeck.SDK.version"
        case nameAndVersion = "TelemetryDeck.SDK.nameAndVersion"
    }

    /// User-configured preference parameters such as language and colour scheme.
    public enum UserPreference: String {
        case language = "TelemetryDeck.UserPreference.language"
        case region = "TelemetryDeck.UserPreference.region"
        case colorScheme = "TelemetryDeck.UserPreference.colorScheme"
        case layoutDirection = "TelemetryDeck.UserPreference.layoutDirection"
    }

    /// System accessibility setting parameters.
    public enum Accessibility: String {
        case isReduceMotionEnabled = "TelemetryDeck.Accessibility.isReduceMotionEnabled"
        case isBoldTextEnabled = "TelemetryDeck.Accessibility.isBoldTextEnabled"
        case isInvertColorsEnabled = "TelemetryDeck.Accessibility.isInvertColorsEnabled"
        case isDarkerSystemColorsEnabled = "TelemetryDeck.Accessibility.isDarkerSystemColorsEnabled"
        case isReduceTransparencyEnabled = "TelemetryDeck.Accessibility.isReduceTransparencyEnabled"
        case shouldDifferentiateWithoutColor = "TelemetryDeck.Accessibility.shouldDifferentiateWithoutColor"
        case preferredContentSizeCategory = "TelemetryDeck.Accessibility.preferredContentSizeCategory"
    }

    /// Calendar context parameters such as day of week and hour of day.
    public enum Calendar: String {
        case dayOfMonth = "TelemetryDeck.Calendar.dayOfMonth"
        case dayOfWeek = "TelemetryDeck.Calendar.dayOfWeek"
        case dayOfYear = "TelemetryDeck.Calendar.dayOfYear"
        case weekOfYear = "TelemetryDeck.Calendar.weekOfYear"
        case isWeekend = "TelemetryDeck.Calendar.isWeekend"
        case monthOfYear = "TelemetryDeck.Calendar.monthOfYear"
        case quarterOfYear = "TelemetryDeck.Calendar.quarterOfYear"
        case hourOfDay = "TelemetryDeck.Calendar.hourOfDay"
    }

    /// User retention metrics parameters.
    public enum Retention: String {
        case totalSessionsCount = "TelemetryDeck.Retention.totalSessionsCount"
        case distinctDaysUsed = "TelemetryDeck.Retention.distinctDaysUsed"
        case distinctDaysUsedLastMonth = "TelemetryDeck.Retention.distinctDaysUsedLastMonth"
        case averageSessionSeconds = "TelemetryDeck.Retention.averageSessionSeconds"
        case previousSessionSeconds = "TelemetryDeck.Retention.previousSessionSeconds"
    }

    /// Acquisition funnel parameters.
    public enum Acquisition: String {
        case firstSessionDate = "TelemetryDeck.Acquisition.firstSessionDate"
        case isNewInstall = "TelemetryDeck.Acquisition.isNewInstall"
        case channel = "TelemetryDeck.Acquisition.channel"
        case leadID = "TelemetryDeck.Acquisition.leadID"
    }

    /// Activation funnel parameters.
    public enum Activation: String {
        case featureName = "TelemetryDeck.Activation.featureName"
    }

    /// Referral and rating parameters.
    public enum Referral: String {
        case receiversCount = "TelemetryDeck.Referral.receiversCount"
        case kind = "TelemetryDeck.Referral.kind"
        case ratingValue = "TelemetryDeck.Referral.ratingValue"
        case ratingComment = "TelemetryDeck.Referral.ratingComment"
    }

    /// Revenue and paywall parameters.
    public enum Revenue: String {
        case paywallShowReason = "TelemetryDeck.Revenue.paywallShowReason"
    }

    /// In-app purchase parameters.
    public enum Purchase: String {
        case type = "TelemetryDeck.Purchase.type"
        case countryCode = "TelemetryDeck.Purchase.countryCode"
        case currencyCode = "TelemetryDeck.Purchase.currencyCode"
        case productID = "TelemetryDeck.Purchase.productID"
    }

    /// Navigation tracking parameters.
    public enum Navigation: String {
        case schemaVersion = "TelemetryDeck.Navigation.schemaVersion"
        case identifier = "TelemetryDeck.Navigation.identifier"
        case sourcePath = "TelemetryDeck.Navigation.sourcePath"
        case destinationPath = "TelemetryDeck.Navigation.destinationPath"
    }

    /// Error reporting parameters.
    public enum Error: String {
        case id = "TelemetryDeck.Error.id"
        case category = "TelemetryDeck.Error.category"
        case message = "TelemetryDeck.Error.message"
    }

    /// Generic event metadata parameters.
    public enum Event: String {
        case durationInSeconds = "TelemetryDeck.Signal.durationInSeconds"
    }
}
