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

public typealias TelemetrySignalType = String
public final class TelemetryManagerConfiguration {
    public let telemetryAppID: String
    public let telemetryServerBaseURL: URL
    public var telemetryAllowDebugBuilds: Bool = false
    public var sessionID: UUID = UUID()
    public var showDebugLogs: Bool = false
    
    /// Instead of specifying a user identifier with each `send` call, you can set your user's name/email/identifier here and
    /// it will be sent with every signal from now on.
    ///
    /// Note that just as with specifying the user identifier with the `send` call, the identifier will never leave the device.
    /// Instead it is used to create a hash, which is included in your signal to allow you to count distinct users.
    public var defaultUser: String?

    public init(appID: String, baseURL: URL? = nil) {
        telemetryAppID = appID

        if let baseURL = baseURL {
            telemetryServerBaseURL = baseURL
        } else {
            telemetryServerBaseURL = URL(string: "https://apptelemetry.io")!
        }
    }
}

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
    ///
    /// It is recommended to call this function when returning from background. If you never call it, your session lasts until your
    /// app is killed and the user restarts it. 
    public static func generateNewSession() {
        TelemetryManager.shared.generateNewSession()
    }
    
    public func generateNewSession() {
        configuration.sessionID = UUID()
    }

    public func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        // Do not send telemetry in DEBUG mode
        #if DEBUG
            if configuration.telemetryAllowDebugBuilds == false {
                print("[Telemetry] Debug is enabled, signal type \(signalType) will not be sent to server.")
                return
            }
        #endif
        
        signalManager.processSignal(signalType, for: clientUser, with: additionalPayload, configuration: configuration)
    }

    private init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration
        self.signalManager = SignalManager(configuration: configuration)
    }

    private static var initializedTelemetryManager: TelemetryManager?

    private let configuration: TelemetryManagerConfiguration
    
    private let signalManager: SignalManager
}
