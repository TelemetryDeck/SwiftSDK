import TelemetryDeck
import Foundation

@objc(TelemetryManagerConfiguration)
public final class TelemetryManagerConfigurationObjCProxy: NSObject {
    fileprivate var telemetryDeckConfiguration: TelemetryDeck.Config

    @objc public init(appID: String, salt: String, baseURL: URL) {
        telemetryDeckConfiguration = TelemetryDeck.Config(appID: appID, salt: salt, baseURL: baseURL)
    }

    @objc public init(appID: String, baseURL: URL) {
        telemetryDeckConfiguration = TelemetryDeck.Config(appID: appID, baseURL: baseURL)
    }

    @objc public init(appID: String, salt: String) {
        telemetryDeckConfiguration = TelemetryDeck.Config(appID: appID, salt: salt)
    }

    @objc public init(appID: String) {
        telemetryDeckConfiguration = TelemetryDeck.Config(appID: appID)
    }

    @objc public var sendNewSessionBeganSignal: Bool {
        get {
            telemetryDeckConfiguration.sendNewSessionBeganSignal
        }

        set {
            telemetryDeckConfiguration.sendNewSessionBeganSignal = newValue
        }
    }

    @objc public var testMode: Bool {
        get {
            telemetryDeckConfiguration.testMode
        }

        set {
            telemetryDeckConfiguration.testMode = newValue
        }
    }

    @objc public var analyticsDisabled: Bool {
        get {
            telemetryDeckConfiguration.analyticsDisabled
        }

        set {
            telemetryDeckConfiguration.analyticsDisabled = newValue
        }
    }
}

@objc(TelemetryManager)
public final class TelemetryManagerObjCProxy: NSObject {
    @objc public static func initialize(with configuration: TelemetryManagerConfigurationObjCProxy) {
        TelemetryDeck.initialize(config: configuration.telemetryDeckConfiguration)
    }

    @objc public static func terminate() {
        TelemetryDeck.terminate()
    }

    @objc public static func send(_ signalName: String, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryDeck.signal(signalName, parameters: additionalPayload, customUserID: clientUser)
    }

    @objc public static func send(_ signalName: String, with additionalPayload: [String: String] = [:]) {
        TelemetryDeck.signal(signalName, parameters: additionalPayload)
    }

    @objc public static func send(_ signalName: String) {
        TelemetryDeck.signal(signalName)
    }

    @objc public static func updateDefaultUser(to newDefaultUser: String?) {
        TelemetryDeck.updateDefaultUserID(to: newDefaultUser)
    }

    @objc public static func generateNewSession() {
        TelemetryDeck.generateNewSession()
    }
}
