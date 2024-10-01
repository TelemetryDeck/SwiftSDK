import Foundation

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

    /// Do not call this method unless you really know what you're doing. The signals will automatically sync with 
    /// the server at appropriate times, there's no need to call this.
    ///
    /// Use this sparingly and only to indicate a time in your app where a signal was just sent but the user is likely 
    /// to leave your app and not return again for a long time.
    ///
    /// This function does not guarantee that the signal cache will be sent right away. Calling this after every 
    /// ``signal(_:parameters:floatValue:customUserID:)`` will not make data reach our servers faster, so avoid 
    /// doing that.
    ///
    /// But if called at the right time (sparingly), it can help ensure the server doesn't miss important churn 
    /// data because a user closes your app and doesn't reopen it anytime soon (if at all).
    public static func requestImmediateSync() {
        TelemetryManager.requestImmediateSync()
    }

    /// Shuts down the SDK and deinitializes the current `TelemetryManager`.
    ///
    /// Once called, you must call `TelemetryManager.initialize(with:)` again before using the manager.
    public static func terminate() {
        TelemetryManager.terminate()
    }

    /// Change the default user identifier sent with each signal.
    ///
    /// Instead of specifying a user identifier with each `signal` call, you can set your user's name/email/identifier here and
    /// it will be sent with every signal from now on. If you still specify a user in the `signal` call, that takes precedence.
    ///
    /// Set to `nil` to disable this behavior.
    ///
    /// Note that just as with specifying the user identifier with the `signal` call, the identifier will never leave the device.
    /// Instead it is used to create a hash, which is included in your signal to allow you to count distinct users.
    public static func updateDefaultUserID(to customUserID: String?) {
        TelemetryManager.updateDefaultUser(to: customUserID)
    }

    /// Generate a new Session ID for all new Signals, in order to begin a new session instead of continuing the old one.
    public static func generateNewSession() {
        TelemetryManager.generateNewSession()
    }
}
