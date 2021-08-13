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


let TelemetryClientVersion = "SwiftClient 1.1.1"

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

    /// If `true`, sends signals even if your scheme's build configuration is set to Debug.
    ///
    /// Defaults to false, which only sends signals if your scheme's build configuration is set to Release.
    public var sendSignalsInDebugConfiguration: Bool = false

    /// Log the current status to the signal cache to the console.
    public var showDebugLogs: Bool = false

    public init(appID: String, baseURL: URL? = nil) {
        telemetryAppID = appID

        if let baseURL = baseURL {
            apiBaseURL = baseURL
        } else {
            apiBaseURL = URL(string: "https://nom.apptelemetry.io")!
        }

        #if os(iOS)
            NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        #elseif os(watchOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: WKExtension.applicationWillEnterForegroundNotification, object: nil)
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
    public static func initialize(with configuration: TelemetryManagerConfiguration) {
        initializedTelemetryManager = TelemetryManager(configuration: configuration)
    }

    public static func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.shared.send(signalType, for: clientUser, with: additionalPayload)
    }

    public static var shared: TelemetryManager {
        guard let telemetryManager = initializedTelemetryManager else {
            fatalError("Please call TelemetryManager.initialize(...) before accessing the shared telemetryManager instance.")
        }

        return telemetryManager
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

    public func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        // Do not send telemetry in DEBUG mode
        #if DEBUG
            if configuration.sendSignalsInDebugConfiguration == false {
                print("[Telemetry] Debug is enabled, signal type \(signalType) will not be sent to server.")
                return
            }
        #endif

        signalManager.processSignal(signalType, for: clientUser, with: additionalPayload, configuration: configuration)
    }

    private init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration
        signalManager = SignalManager(configuration: configuration)
    }

    private static var initializedTelemetryManager: TelemetryManager?

    private let configuration: TelemetryManagerConfiguration

    private let signalManager: SignalManager
}
