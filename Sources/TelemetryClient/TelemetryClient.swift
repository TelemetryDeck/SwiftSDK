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

let TelemetryClientVersion = "SwiftClient 1.3.1"

public typealias TelemetrySignalType = String

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
    public var sessionID = UUID() { didSet { if sendNewSessionBeganSignal { TelemetryManager.send("newSessionBegan") } } }

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
    public var showDebugLogs: Bool = false

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

    public static func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, floatValue: Double? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.shared.send(signalType, for: clientUser, floatValue: floatValue, with: additionalPayload)
    }

    public static var shared: TelemetryManager {
        if let telemetryManager = initializedTelemetryManager {
           return telemetryManager
        } else if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Xcode is building and running the app for SwiftUI Previews, this is not a real launch of the app, therefore mock data is used
            self.initializedTelemetryManager = .init(configuration: .init(appID: ""))
            return self.initializedTelemetryManager!
        } else {
            fatalError("Please call TelemetryManager.initialize(...) before accessing the shared telemetryManager instance.")
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
    public func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, floatValue: Double? = nil, with additionalPayload: [String: String] = [:]) {
        // make sure to not send any signals when run by Xcode via SwiftUI previews
        guard !self.configuration.swiftUIPreviewMode, !self.configuration.analyticsDisabled else { return }

        signalManager.processSignal(signalType, for: clientUser, floatValue: floatValue, with: additionalPayload, configuration: configuration)
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

    @objc public static func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.send(signalType, for: clientUser, with: additionalPayload)
    }

    @objc public static func send(_ signalType: TelemetrySignalType, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.send(signalType, with: additionalPayload)
    }

    @objc public static func send(_ signalType: TelemetrySignalType) {
        TelemetryManager.send(signalType)
    }

    @objc public static func updateDefaultUser(to newDefaultUser: String?) {
        TelemetryManager.updateDefaultUser(to: newDefaultUser)
    }

    @objc public static func generateNewSession() {
        TelemetryManager.generateNewSession()
    }
}
