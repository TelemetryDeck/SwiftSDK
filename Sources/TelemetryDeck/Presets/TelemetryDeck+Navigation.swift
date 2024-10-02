import Foundation

extension TelemetryDeck {
    /// Send a signal that represents a navigation event with a source and a destination
    ///
    /// This is a convenience method that will internally send a completely normal TelemetryDeck signals with the type
    /// `TelemetryDeck.Route.Transition.navigation` and the necessary parameters.
    ///
    /// Since TelemetryDeck navigation signals need a source and a destination, this method will store the last
    /// used destination for use in the `navigate(to:)` method.
    ///
    /// ## Navigation Paths
    /// Navigation Paths are strings that describe a location or view in your application or website. They must be
    /// delineated by either `.` or `/` characters. Delineation characters at the beginning and end of the string are
    /// ignored. Use the empty string `""` for navigation from outside the app. Examples are `index`,
    /// `settings.user.changePassword`, or `/blog/ios-market-share`.
    ///
    /// - Parameters:
    ///     - from: The navigation path at the beginning of the navigation event, identifying the view the user is leaving
    ///     - to: The navigation path at the end of the navigation event, identifying the view the user is arriving at
    ///     - customUserID: An optional string specifying a custom user identifier. If provided, it will override the default user identifier from the configuration. Default is `nil`.
    @MainActor
    public static func navigationPathChanged(from source: String, to destination: String, customUserID: String? = nil) {
        NavigationStatus.shared.previousNavigationPath = destination

        self.signal(
            "TelemetryDeck.Navigation.pathChanged",
            parameters: [
                "TelemetryDeck.Navigation.schemaVersion": "1",
                "TelemetryDeck.Navigation.identifier": "\(source) -> \(destination)",
                "TelemetryDeck.Navigation.sourcePath": source,
                "TelemetryDeck.Navigation.destinationPath": destination
            ],
            customUserID: customUserID
        )
    }

    /// Send a signal that represents a navigation event with a destination and a default source.
    ///
    /// This is a convenience method that will internally send a completely normal TelemetryDeck signals with the type
    /// `TelemetryDeck.Route.Transition.navigation` and the necessary parameters.
    ///
    /// ## Navigation Paths
    /// Navigation Paths are strings that describe a location or view in your application or website. They must be
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
    @MainActor
    public static func navigationPathChanged(to destination: String, customUserID: String? = nil) {
        let source = NavigationStatus.shared.previousNavigationPath ?? ""

        Self.navigationPathChanged(from: source, to: destination, customUserID: customUserID)
    }

    @MainActor
    @available(*, unavailable, renamed: "navigationPathChanged(from:to:customUserID:)")
    public static func navigate(from source: String, to destination: String, customUserID: String? = nil) {
        self.navigationPathChanged(from: source, to: destination, customUserID: customUserID)
    }

    @MainActor
    @available(*, unavailable, renamed: "navigationPathChanged(to:customUserID:)")
    public static func navigate(to destination: String, customUserID: String? = nil) {
        self.navigationPathChanged(to: destination, customUserID: customUserID)
    }
}
