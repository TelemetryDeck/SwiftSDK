import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#elseif os(watchOS)
    import WatchKit
#elseif os(tvOS)
    import TVUIKit
#endif

let TelemetryClientVersion = "1.5.1"

/// Configuration for TelemetryManager
///
/// Use an instance of this class to specify settings for TelemetryManager. If these settings change during the course of
/// your runtime, it might be a good idea to hold on to the instance and update it as needed. TelemetryManager's behaviour
/// will update as well.
public final class TelemetryManagerConfiguration {
    /// Your app's ID for Telemetry. Set this during initialization.
    public let telemetryAppID: String

    /// The domain to send signals to. Defaults to the default Telemetry API server.
    /// (Don't change this unless you know exactly what you're doing)
    public let apiBaseURL: URL

    /// This string will be appended to to all user identifiers before hashing them.
    ///
    /// Set the salt to a random string of 64 letters, integers and special characters to prevent the unlikely
    /// possibility of uncovering the original user identifiers through calculation.
    ///
    /// Note: Once you set the salt, it should not change. If you change the salt, every single one of your
    /// user identifers wll be different, so even existing users will look like new users to TelemetryDeck.
    public let salt: String

    /// Instead of specifying a user identifier with each `send` call, you can set your user's name/email/identifier here and
    /// it will be sent with every signal from now on.
    ///
    /// Note that just as with specifying the user identifier with the `send` call, the identifier will never leave the device.
    /// Instead it is used to create a hash, which is included in your signal to allow you to count distinct users.
    public var defaultUser: String?

    /// If `true`, sends a "newSessionBegan" Signal on each app foreground or cold launch
    ///
    /// Defaults to true. Set to false to prevent automatically sending this signal.
    public var sendNewSessionBeganSignal: Bool = true

    /// A random identifier for the current user session.
    ///
    /// On iOS, tvOS, and watchOS, the session identifier will automatically update whenever your app returns from background, or if it is
    /// launched from cold storage. On other platforms, a new identifier will be generated each time your app launches. If you'd like
    /// more fine-grained session support, write a new random session identifier into this property each time a new session begins.
    ///
    /// Beginning a new session automatically sends a "newSessionBegan" Signal if `sendNewSessionBeganSignal` is `true`
    public var sessionID = UUID() {
        didSet {
            if sendNewSessionBeganSignal {
                TelemetryManager.send("newSessionBegan")
                TelemetryDeck.signal("TelemetryDeck.Session.started")
            }
        }
    }

    @available(*, deprecated, message: "Please use the testMode property instead")
    public var sendSignalsInDebugConfiguration: Bool = false

    /// If `true` any signals sent will be marked as *Testing* signals.
    ///
    /// Testing signals are only shown when your Telemetry Viewer App is in Testing mode. In live mode, they are ignored.
    ///
    /// By default, this is the same value as `DEBUG`, i.e. you'll be in Testing Mode when you develop and in live mode when
    /// you release. You can manually override this, however.
    public var testMode: Bool {
        get {
            if let testMode = _testMode { return testMode }

            #if DEBUG
                return true
            #else
                return false
            #endif
        }

        set { _testMode = newValue }
    }

    private var _testMode: Bool?

    /// If `true` no signals will be sent.
    ///
    /// SwiftUI previews are built by Xcode automatically and events sent during this mode are not considered actual user-initiated usage.
    ///
    /// By default, this checks for the `XCODE_RUNNING_FOR_PREVIEWS` environment variable as described in this StackOverflow answer:
    /// https://stackoverflow.com/a/61741858/3451975
    public var swiftUIPreviewMode: Bool {
        get {
            if let swiftUIPreviewMode = _swiftUIPreviewMode { return swiftUIPreviewMode }

            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return true
            } else {
                return false
            }
        }

        set { _swiftUIPreviewMode = newValue }
    }

    private var _swiftUIPreviewMode: Bool?

    /// If `true` no signals will be sent.
    ///
    /// Can be used to manually opt out users of tracking.
    ///
    /// Works together with `swiftUIPreviewMode` if either of those values is `true` no analytics events are sent.
    /// However it won't interfere with SwiftUI Previews, when explicitly settings this value to `false`.
    public var analyticsDisabled: Bool = false

    /// Log the current status to the signal cache to the console.
    @available(*, deprecated, message: "Please use the logHandler property instead")
    public var showDebugLogs: Bool = false

    /// A strategy for handling logs.
    ///
    /// Defaults to `print` with info/errror messages - debug messages are not outputted. Set to `nil` to disable all logging from TelemetryDeck SDK.
    ///
    /// - NOTE: If ``swiftUIPreviewMode`` is `true` (by default only when running SwiftUI previews), this value is effectively ignored, working like it's set to `nil`.
    public var logHandler: LogHandler? = LogHandler.stdout(.info)

    /// An array of signal metadata enrichers: a system for adding dynamic metadata to signals as they are recorded.
    ///
    /// Defaults to an empty array.
    public var metadataEnrichers: [SignalEnricher] = []

    public init(appID: String, salt: String? = nil, baseURL: URL? = nil) {
        telemetryAppID = appID

        if let baseURL = baseURL {
            apiBaseURL = baseURL
        } else {
            apiBaseURL = URL(string: "https://nom.telemetrydeck.com")!
        }

        if let salt = salt {
            self.salt = salt
        } else {
            self.salt = ""
        }

        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        #elseif os(watchOS)
            if #available(watchOS 7.0, *) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: WKExtension.applicationWillEnterForegroundNotification, object: nil)
                }
            } else {
                // Pre watchOS 7.0, this library will not use multiple sessions after backgrounding since there are no notifications we can observe.
            }
        #elseif os(tvOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            }
        #endif
    }

    #if os(iOS) || os(watchOS) || os(tvOS)
        @objc func didEnterForeground() {
            // generate a new session identifier
            sessionID = UUID()
        }
    #endif

    @available(*, deprecated, renamed: "sendSignalsInDebugConfiguration")
    public var telemetryAllowDebugBuilds: Bool {
        get { return sendSignalsInDebugConfiguration }
        set { sendSignalsInDebugConfiguration = newValue }
    }
}

/// Accepts signals that signify events in your app's life cycle, collects and caches them, and pushes them to the Telemetry API.
///
/// Use an instance of `TelemetryManagerConfiguration` to configure this at initialization and during its lifetime.
public class TelemetryManager {
    /// Returns `true` when the TelemetryManager already has been initialized correctly, `false` otherwise.
    public static var isInitialized: Bool {
        initializedTelemetryManager != nil
    }

    @available(*, deprecated, renamed: "TelemetryDeck.initialize(configuration:)", message: "This call was renamed to `TelemetryDeck.initialize(configuration:)`. Please migrate – a fix-it is available.")
    public static func initialize(with configuration: TelemetryManagerConfiguration) {
        initializedTelemetryManager = TelemetryManager(configuration: configuration)
    }

    internal static func initialize(with configuration: TelemetryManagerConfiguration, signalManager: SignalManageable) {
        initializedTelemetryManager = TelemetryManager(configuration: configuration, signalManager: signalManager)
    }
    /// Shuts down the SDK and deinitializes the current `TelemetryManager`.
    ///
    /// Once called, you must call `TelemetryManager.initialize(with:)` again before using the manager.
    public static func terminate() {
        initializedTelemetryManager = nil
    }

    /// Send a Signal to TelemetryDeck, to record that an event has occurred.
    ///
    /// If you specify a payload, it will be sent in addition to the default payload which includes OS Version, App Version, and more.
    @available(*, deprecated, renamed: "TelemetryDeck.signal(_:parameters:)", message: "This call was renamed to `TelemetryDeck.signal(_:parameters:)`. Please migrate – a fix-it is available.")
    public static func send(_ signalName: String, with parameters: [String: String] = [:]) {
        send(signalName, for: nil, floatValue: nil, with: parameters)
    }

    /// Send a Signal to TelemetryDeck, to record that an event has occurred.
    ///
    /// If you specify a user identifier here, it will take precedence over the default user identifier specified in the `TelemetryManagerConfiguration`.
    ///
    /// If you specify a payload, it will be sent in addition to the default payload which includes OS Version, App Version, and more.
    @_disfavoredOverload
    @available(*, deprecated, message: "This call was renamed to `TelemetryDeck.signal(_:parameters:floatValue:customUserID:)`. Please migrate – no fix-it possible due to the changed order of arguments.")
    public static func send(_ signalName: String, for customUserID: String? = nil, floatValue: Double? = nil, with parameters: [String: String] = [:]) {
        TelemetryManager.shared.send(signalName, for: customUserID, floatValue: floatValue, with: parameters)
    }

    /// Do not call this method unless you really know what you're doing. The signals will automatically sync with the server at appropriate times, there's no need to call this.
    ///
    /// Use this sparingly and only to indicate a time in your app where a signal was just sent but the user is likely to leave your app and not return again for a long time.
    ///
    /// This function does not guarantee that the signal cache will be sent right away. Calling this after every ``send`` will not make data reach our servers faster, so avoid doing that.
    /// But if called at the right time (sparingly), it can help ensure the server doesn't miss important churn data because a user closes your app and doesn't reopen it anytime soon (if at all).
    public static func requestImmediateSync() {
        TelemetryManager.shared.requestImmediateSync()
    }

    public static var shared: TelemetryManager {
        if let telemetryManager = initializedTelemetryManager {
           return telemetryManager
        } else if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Xcode is building and running the app for SwiftUI Previews, this is not a real launch of the app, therefore mock data is used
            self.initializedTelemetryManager = .init(configuration: .init(appID: ""))
            return self.initializedTelemetryManager!
        } else {
            assertionFailure("Please call TelemetryManager.initialize(...) before accessing the shared telemetryManager instance.")
            return .init(configuration: .init(appID: ""))
        }

    }

    /// Change the default user identifier sent with each signal.
    ///
    /// Instead of specifying a user identifier with each `send` call, you can set your user's name/email/identifier here and
    /// it will be sent with every signal from now on. If you still specify a user in the `send` call, that takes precedence.
    ///
    /// Set to `nil` to disable this behavior.
    ///
    /// Note that just as with specifying the user identifier with the `send` call, the identifier will never leave the device.
    /// Instead it is used to create a hash, which is included in your signal to allow you to count distinct users.
    public static func updateDefaultUser(to newDefaultUser: String?) {
        TelemetryManager.shared.updateDefaultUser(to: newDefaultUser)
    }

    public func updateDefaultUser(to newDefaultUser: String?) {
        configuration.defaultUser = newDefaultUser
    }

    /// Generate a new Session ID for all new Signals, in order to begin a new session instead of continuing the old one.
    public static func generateNewSession() {
        TelemetryManager.shared.generateNewSession()
    }

    public func generateNewSession() {
        configuration.sessionID = UUID()
    }

    /// Send a Signal to TelemetryDeck, to record that an event has occurred.
    ///
    /// If you specify a user identifier here, it will take precedence over the default user identifier specified in the `TelemetryManagerConfiguration`.
    ///
    /// If you specify a payload, it will be sent in addition to the default payload which includes OS Version, App Version, and more.
    @available(*, deprecated, message: "This call was renamed to `TelemetryDeck.signal(_:parameters:floatValue:customUserID:)`. Please migrate – no fix-it possible due to the changed order of arguments.")
    public func send(_ signalName: String, with parameters: [String: String] = [:]) {
        send(signalName, for: nil, floatValue: nil, with: parameters)
    }

    /// Send a Signal to TelemetryDeck, to record that an event has occurred.
    ///
    /// If you specify a user identifier here, it will take precedence over the default user identifier specified in the `TelemetryManagerConfiguration`.
    ///
    /// If you specify a payload, it will be sent in addition to the default payload which includes OS Version, App Version, and more.
    @_disfavoredOverload
    @available(*, deprecated, message: "This call was renamed to `TelemetryDeck.signal(_:parameters:floatValue:customUserID:)`. Please migrate – no fix-it possible due to the changed order of arguments.")
    public func send(_ signalName: String, for customUserID: String? = nil, floatValue: Double? = nil, with parameters: [String: String] = [:]) {
        // make sure to not send any signals when run by Xcode via SwiftUI previews
        guard !self.configuration.swiftUIPreviewMode, !self.configuration.analyticsDisabled else { return }

        signalManager.processSignal(signalName, parameters: parameters, floatValue: floatValue, customUserID: customUserID, configuration: configuration)
    }

    /// Do not call this method unless you really know what you're doing. The signals will automatically sync with the server at appropriate times, there's no need to call this.
    /// 
    /// Use this sparingly and only to indicate a time in your app where a signal was just sent but the user is likely to leave your app and not return again for a long time.
    /// 
    /// This function does not guarantee that the signal cache will be sent right away. Calling this after every ``send`` will not make data reach our servers faster, so avoid doing that.
    /// But if called at the right time (sparingly), it can help ensure the server doesn't miss important churn data because a user closes your app and doesn't reopen it anytime soon (if at all).
    public func requestImmediateSync() {
        // this check ensures that the number of requests can only double in the worst case where a developer calls this after each `send`
        if Date().timeIntervalSince(lastTimeImmediateSyncRequested) > SignalManager.minimumSecondsToPassBetweenRequests {
            lastTimeImmediateSyncRequested = Date()

            // give the signal manager some short amount of time to process the signal that was sent right before calling sync
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
                self?.signalManager.attemptToSendNextBatchOfCachedSignals()
            }
        }
    }

    private init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration
        signalManager = SignalManager(configuration: configuration)
    }

    private init(configuration: TelemetryManagerConfiguration, signalManager: SignalManageable) {
        self.configuration = configuration
        self.signalManager = signalManager
    }

    private static var initializedTelemetryManager: TelemetryManager?

    private let configuration: TelemetryManagerConfiguration

    private let signalManager: SignalManageable

    private var lastTimeImmediateSyncRequested: Date = .distantPast
}

@objc(TelemetryManagerConfiguration)
public final class TelemetryManagerConfigurationObjCProxy: NSObject {
    fileprivate var telemetryManagerConfiguration: TelemetryManagerConfiguration

    @objc public init(appID: String, salt: String, baseURL: URL) {
        self.telemetryManagerConfiguration = TelemetryManagerConfiguration(appID: appID, salt: salt, baseURL: baseURL)
    }

    @objc public init(appID: String, baseURL: URL) {
        self.telemetryManagerConfiguration = TelemetryManagerConfiguration(appID: appID, baseURL: baseURL)
    }

    @objc public init(appID: String, salt: String) {
        self.telemetryManagerConfiguration = TelemetryManagerConfiguration(appID: appID, salt: salt)
    }

    @objc public init(appID: String) {
        self.telemetryManagerConfiguration = TelemetryManagerConfiguration(appID: appID)
    }

    @objc public var sendNewSessionBeganSignal: Bool {
        get {
            telemetryManagerConfiguration.sendNewSessionBeganSignal
        }

        set {
            telemetryManagerConfiguration.sendNewSessionBeganSignal = newValue
        }
    }

    @objc public var testMode: Bool {
        get {
            telemetryManagerConfiguration.testMode
        }

        set {
            telemetryManagerConfiguration.testMode = newValue
        }
    }

    @objc public var analyticsDisabled: Bool {
        get {
            telemetryManagerConfiguration.analyticsDisabled
        }

        set {
            telemetryManagerConfiguration.analyticsDisabled = newValue
        }
    }
}

@objc(TelemetryManager)
public final class TelemetryManagerObjCProxy: NSObject {
    @objc public static func initialize(with configuration: TelemetryManagerConfigurationObjCProxy) {
        TelemetryManager.initialize(with: configuration.telemetryManagerConfiguration)
    }

    @objc public static func terminate() {
        TelemetryManager.terminate()
    }

    @objc public static func send(_ signalName: String, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.send(signalName, for: clientUser, with: additionalPayload)
    }

    @objc public static func send(_ signalName: String, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.send(signalName, with: additionalPayload)
    }

    @objc public static func send(_ signalName: String) {
        TelemetryManager.send(signalName)
    }

    @objc public static func updateDefaultUser(to newDefaultUser: String?) {
        TelemetryManager.updateDefaultUser(to: newDefaultUser)
    }

    @objc public static func generateNewSession() {
        TelemetryManager.generateNewSession()
    }
}
