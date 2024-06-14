import Foundation

/// This internal singleton keeps track of the last used navigation path so
/// that the `navigate(to:)` function has a source to work off of.
class TelemetryDeckNavigationStatus {
    var previousNavigationPath: String?
    static let shared = TelemetryDeckNavigationStatus()
}

/// A namespace for TelemetryDeck related functionalities.
public enum TelemetryDeck {
    /// This alias makes it easier to migrate the configuration type into the TelemetryDeck namespace in future versions when deprecated code is fully removed.
    public typealias Config = TelemetryManagerConfiguration

    /// Initializes TelemetryDeck with a customizable configuration.
    ///
    /// - Parameter configuration: An instance of `Configuration` which includes all the settings required to configure TelemetryDeck.
    ///
    /// This function sets up the telemetry system with the specified configuration. It is necessary to call this method before sending any telemetry signals.
    /// For example, you might want to call this in your `init` method of your app's `@main` entry point.
    public static func initialize(config: Config) {
        TelemetryManager.initialize(with: config)
    }

    /// Sends a telemetry signal with optional parameters to TelemetryDeck.
    ///
    /// - Parameters:
    ///   - signalName: The name of the signal to be sent. This is a string that identifies the type of event or action being reported.
    ///   - parameters: A dictionary of additional string key-value pairs that provide further context about the signal. Default is empty.
    ///   - floatValue: An optional floating-point number that can be used to provide numerical data about the signal. Default is `nil`.
    ///   - customUserID: An optional string specifying a custom user identifier. If provided, it will override the default user identifier from the configuration. Default is `nil`.
    ///
    /// This function wraps the `TelemetryManager.send` method, providing a streamlined way to send signals from anywhere in the app.
    public static func signal(
        _ signalName: String,
        parameters: [String: String] = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        TelemetryManager.send(signalName, for: customUserID, floatValue: floatValue, with: parameters)
    }

    /// Send a signal that represents a navigation event with a source and a destination
    ///
    /// This is a convenience method that will internally send a completely normal TelemetryDeck signals with the type
    /// `TelemetryDeck.Route.Transition.navigation` and the necessary payload.
    ///
    /// Since TelemetryDeck navigation signals need a source and a destination, this method will keep track of the last
    /// used destination for use in the `navigate(to:)` method.
    ///
    /// ## Navigation Paths
    /// Navigation Paths are strings that indicate a location or view in your application or website. They must be
    /// delineated by either `.` or `/` characters. Delineation characters at the beginning and end of the string are
    /// ignored. Use the empty string `""` for navigation from outside the app. Examples are `index`,
    /// `settings.user.changePassword`, or `/blog/ios-market-share`.
    ///
    /// - Parameters:
    ///     - from: The navigation path at the beginning of the navigation event, identifying the view the user is leaving
    ///     - to: The navigation path at the end of the navigation event, identifying the view the user is arriving at
    ///     - customUserID: An optional string specifying a custom user identifier. If provided, it will override the default user identifier from the configuration. Default is `nil`.
    public static func navigate(from source: String, to destination: String, customUserID: String? = nil) {
        TelemetryDeckNavigationStatus.shared.previousNavigationPath = destination

        TelemetryManager.send(
            "TelemetryDeck.Route.Transition.navigation",
            for: customUserID,
            with: [
                "TelemetryDeck.Route.Transition.schemaVersion": "1",
                "TelemetryDeck.Route.Transition.identifier": "\(source) -> \(destination)",
                "TelemetryDeck.Route.Transition.source": source,
                "TelemetryDeck.Route.Transition.destination": destination
            ]
        )
    }

    /// Send a signal that represents a navigation event with a destination and a default source.
    ///
    /// This is a convenience method that will internally send a completely normal TelemetryDeck signals with the type
    /// `TelemetryDeck.Route.Transition.navigation` and the necessary payload.
    ///
    /// ## Navigation Paths
    /// Navigation Paths are strings that indicate a location or view in your application or website. They must be
    /// delineated by either `.` or `/` characters. Delineation characters at the beginning and end of the string are
    /// ignored. Use the empty string `""` for navigation from outside the app. Examples are `index`,
    /// `settings.user.changePassword`, or `/blog/ios-market-share`.
    ///
    /// ## Automatic Navigation Tracking
    /// Since TelemetryDeck navigation signals need a source and a destination, this method will keep track of the last
    /// used destination and will automatically insert it as a source the next time you call this method.
    ///
    /// This is very convenient, but will produce incorrect graphs if you don't call it from every screen in your app.
    /// Suppose you have 3 tabs "Home", "User" and "Settings", but only set up navigation in "Home" and "Settings". If
    /// a user taps "Home", "User" and "Settings" in that order, that'll produce an incorrect navigation signal with
    /// source "Home" and destination "Settings", a path that the user did not take.
    ///
    /// - Parameters:
    ///     - to: The navigation path representing the view the user is arriving at.
    ///     - customUserID: An optional string specifying a custom user identifier. If provided, it will override the default user identifier from the configuration. Default is `nil`.
    public static func navigate(to destination: String, customUserID: String? = nil) {
        let source = TelemetryDeckNavigationStatus.shared.previousNavigationPath ?? ""
        Self.navigate(from: source, to: destination, customUserID: customUserID)
    }

    /// Do not call this method unless you really know what you're doing. The signals will automatically sync with the server at appropriate times, there's no need to call this.
    ///
    /// Use this sparingly and only to indicate a time in your app where a signal was just sent but the user is likely to leave your app and not return again for a long time.
    ///
    /// This function does not guarantee that the signal cache will be sent right away. Calling this after every ``signal(_:parameters:floatValue:customUserID:)`` will not make data reach our servers faster, so avoid doing that.
    /// But if called at the right time (sparingly), it can help ensure the server doesn't miss important churn data because a user closes your app and doesn't reopen it anytime soon (if at all).
    public static func requestImmediateSync() {
        TelemetryManager.requestImmediateSync()
    }
}
