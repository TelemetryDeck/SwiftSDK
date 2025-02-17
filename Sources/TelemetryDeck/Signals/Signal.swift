import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
    import IOKit
#elseif os(watchOS)
    import WatchKit
#elseif os(tvOS)
    import TVUIKit
#endif

/// Note: only use this when posting to the deprecated V1 ingest API
struct SignalPostBody: Codable, Equatable {
    /// When was this signal generated
    let receivedAt: Date

    /// The App ID of this signal
    let appID: String

    /// A user identifier. This should be hashed on the client, and will be hashed + salted again
    /// on the server to break any connection to personally identifiable data.
    let clientUser: String

    /// A randomly generated session identifier. Should be the same over the course of the session
    let sessionID: String

    /// A type name for this signal that describes the event that triggered the signal
    let type: String

    /// An optional numerical value to send along with the signal.
    let floatValue: Double?

    /// Tags in the form "key:value" to attach to the signal
    let payload: [String: String]

    /// If "true", mark the signal as a testing signal and only show it in a dedicated test mode UI
    let isTestMode: String
}

/// The default payload that is included in payloads processed by TelemetryDeck.
public struct DefaultSignalPayload: Encodable {
    @MainActor
    public static var parameters: [String: String] {
        var parameters: [String: String] = [
            // deprecated names
            "platform": Self.platform,
            "systemVersion": Self.systemVersion,
            "majorSystemVersion": Self.majorSystemVersion,
            "majorMinorSystemVersion": Self.majorMinorSystemVersion,
            "appVersion": Self.appVersion,
            "buildNumber": Self.buildNumber,
            "isSimulator": "\(Self.isSimulator)",
            "isDebug": "\(Self.isDebug)",
            "isTestFlight": "\(Self.isTestFlight)",
            "isAppStore": "\(Self.isAppStore)",
            "modelName": Self.modelName,
            "architecture": Self.architecture,
            "operatingSystem": Self.operatingSystem,
            "targetEnvironment": Self.targetEnvironment,
            "locale": Self.locale,
            "region": Self.region,
            "appLanguage": Self.appLanguage,
            "preferredLanguage": Self.preferredLanguage,
            "telemetryClientVersion": sdkVersion,

            // new names
            "TelemetryDeck.AppInfo.buildNumber": Self.buildNumber,
            "TelemetryDeck.AppInfo.version": Self.appVersion,
            "TelemetryDeck.AppInfo.versionAndBuildNumber": "\(Self.appVersion) (build \(Self.buildNumber))",

            "TelemetryDeck.Device.architecture": Self.architecture,
            "TelemetryDeck.Device.modelName": Self.modelName,
            "TelemetryDeck.Device.operatingSystem": Self.operatingSystem,
            "TelemetryDeck.Device.orientation": Self.orientation,
            "TelemetryDeck.Device.platform": Self.platform,
            "TelemetryDeck.Device.screenResolutionHeight": Self.screenResolutionHeight,
            "TelemetryDeck.Device.screenResolutionWidth": Self.screenResolutionWidth,
            "TelemetryDeck.Device.screenScaleFactor": Self.screenScaleFactor,
            "TelemetryDeck.Device.systemMajorMinorVersion": Self.majorMinorSystemVersion,
            "TelemetryDeck.Device.systemMajorVersion": Self.majorSystemVersion,
            "TelemetryDeck.Device.systemVersion": Self.systemVersion,
            "TelemetryDeck.Device.timeZone": Self.timeZone,

            "TelemetryDeck.RunContext.isAppStore": "\(Self.isAppStore)",
            "TelemetryDeck.RunContext.isDebug": "\(Self.isDebug)",
            "TelemetryDeck.RunContext.isSimulator": "\(Self.isSimulator)",
            "TelemetryDeck.RunContext.isTestFlight": "\(Self.isTestFlight)",
            "TelemetryDeck.RunContext.language": Self.appLanguage,
            "TelemetryDeck.RunContext.locale": Self.locale,
            "TelemetryDeck.RunContext.targetEnvironment": Self.targetEnvironment,

            "TelemetryDeck.SDK.name": "SwiftSDK",
            "TelemetryDeck.SDK.nameAndVersion": "SwiftSDK \(sdkVersion)",
            "TelemetryDeck.SDK.version": sdkVersion,

            "TelemetryDeck.UserPreference.colorScheme": Self.colorScheme,
            "TelemetryDeck.UserPreference.language": Self.preferredLanguage,
            "TelemetryDeck.UserPreference.layoutDirection": Self.layoutDirection,
            "TelemetryDeck.UserPreference.region": Self.region,
        ]

        parameters.merge(self.accessibilityParameters, uniquingKeysWith: { $1 })
        parameters.merge(self.calendarParameters, uniquingKeysWith: { $1 })

        if let extensionIdentifier = Self.extensionIdentifier {
            // deprecated name
            parameters["extensionIdentifier"] = extensionIdentifier

            // new name
            parameters["TelemetryDeck.RunContext.extensionIdentifier"] = extensionIdentifier
        }

        // Pirate Metrics
        if #available(watchOS 7, *) {
            parameters.merge(
                [
                    "TelemetryDeck.Acquisition.firstSessionDate": SessionManager.shared.firstSessionDate,
                    "TelemetryDeck.Retention.averageSessionSeconds": "\(SessionManager.shared.averageSessionSeconds)",
                    "TelemetryDeck.Retention.distinctDaysUsed": "\(SessionManager.shared.distinctDaysUsed.count)",
                    "TelemetryDeck.Retention.distinctDaysUsedLastMonth": "\(SessionManager.shared.distinctDaysUsedLastMonthCount)",
                    "TelemetryDeck.Retention.totalSessionsCount": "\(SessionManager.shared.totalSessionsCount)",
                ],
                uniquingKeysWith: { $1 }
            )

            if let previousSessionSeconds = SessionManager.shared.previousSessionSeconds {
                parameters["TelemetryDeck.Retention.previousSessionSeconds"] = "\(previousSessionSeconds)"
            }
        }

        return parameters
    }
}
