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

        if let extensionIdentifier = Self.extensionIdentifier {
            // deprecated name
            parameters["extensionIdentifier"] = extensionIdentifier

            // new name
            parameters["TelemetryDeck.RunContext.extensionIdentifier"] = extensionIdentifier
        }

        return parameters
    }
}

// MARK: - Helpers

extension DefaultSignalPayload {
    @MainActor
    static var accessibilityParameters: [String: String] {
        var a11yParams: [String: String] = [:]

        #if os(iOS) || os(tvOS)
        a11yParams["TelemetryDeck.Accessibility.isReduceMotionEnabled"] = "\(UIAccessibility.isReduceMotionEnabled)"
        a11yParams["TelemetryDeck.Accessibility.isBoldTextEnabled"] = "\(UIAccessibility.isBoldTextEnabled)"
        a11yParams["TelemetryDeck.Accessibility.isInvertColorsEnabled"] = "\(UIAccessibility.isInvertColorsEnabled)"
        a11yParams["TelemetryDeck.Accessibility.isDarkerSystemColorsEnabled"] = "\(UIAccessibility.isDarkerSystemColorsEnabled)"
        a11yParams["TelemetryDeck.Accessibility.isReduceTransparencyEnabled"] = "\(UIAccessibility.isReduceTransparencyEnabled)"
        if #available(iOS 13.0, *) {
            a11yParams["TelemetryDeck.Accessibility.shouldDifferentiateWithoutColor"] = "\(UIAccessibility.shouldDifferentiateWithoutColor)"
        }
        a11yParams["TelemetryDeck.Accessibility.preferredContentSizeCategory"] = UIApplication.shared.preferredContentSizeCategory.rawValue
            .replacingOccurrences(of: "UICTContentSizeCategory", with: "")  // replaces output "UICTContentSizeCategoryL" with "L"
        #elseif os(macOS)
        if let systemPrefs = UserDefaults.standard.persistentDomain(forName: "com.apple.universalaccess") {
            a11yParams["TelemetryDeck.Accessibility.isReduceMotionEnabled"] = "\(systemPrefs["reduceMotion"] as? Bool ?? false)"
            a11yParams["TelemetryDeck.Accessibility.isInvertColorsEnabled"] = "\(systemPrefs["InvertColors"] as? Bool ?? false)"
        }
        #endif

        return a11yParams
    }

    static var isSimulatorOrTestFlight: Bool {
        isSimulator || isTestFlight
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    static var isDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    static var isTestFlight: Bool {
        guard !isDebug, let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("sandboxReceipt")
    }

    static var isAppStore: Bool {
        #if DEBUG
            return false
        #elseif TARGET_OS_OSX || TARGET_OS_MACCATALYST
            return false
        #elseif targetEnvironment(simulator)
            return false
        #else
            return !isSimulatorOrTestFlight
        #endif
    }

    /// The operating system and its version
    static var systemVersion: String {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let minorVersion = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
        let patchVersion = ProcessInfo.processInfo.operatingSystemVersion.patchVersion
        return "\(platform) \(majorVersion).\(minorVersion).\(patchVersion)"
    }

    /// The major system version, i.e. iOS 15
    static var majorSystemVersion: String {
        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }

    /// The major system version, i.e. iOS 15
    static var majorMinorSystemVersion: String {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let minorVersion = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
        return "\(platform) \(majorVersion).\(minorVersion)"
    }

    /// The Bundle Short Version String, as described in Info.plist
    static var appVersion: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return appVersion ?? "0"
    }

    /// The Bundle Version String, as described in Info.plist
    static var buildNumber: String {
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return buildNumber ?? "0"
    }

    /// The extension identifer for the active resource, if available.
    ///
    /// This provides a value such as `com.apple.widgetkit-extension` when TelemetryDeck is run from a widget.
    static var extensionIdentifier: String? {
        let container = Bundle.main.infoDictionary?["NSExtension"] as? [String: Any]
        return container?["NSExtensionPointIdentifier"] as? String
    }

    /// The modelname as reported by systemInfo.machine
    static var modelName: String {
        #if os(iOS)
            if #available(iOS 14.0, *) {
                if ProcessInfo.processInfo.isiOSAppOnMac {
                    var size = 0
                    sysctlbyname("hw.model", nil, &size, nil, 0)
                    var machine = [CChar](repeating: 0, count: size)
                    sysctlbyname("hw.model", &machine, &size, nil, 0)
                    return String(cString: machine)
                }
            }
        #endif

        #if os(macOS)
            if #available(macOS 11, *) {
                let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
                var modelIdentifier: String?

                if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
                    if let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
                        modelIdentifier = String(cString: modelIdentifierCString)
                    }
                }

                IOObjectRelease(service)
                if let modelIdentifier = modelIdentifier {
                    return modelIdentifier
                }
            }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// The build architecture
    static var architecture: String {
        #if arch(x86_64)
            return "x86_64"
        #elseif arch(arm)
            return "arm"
        #elseif arch(arm64)
            return "arm64"
        #elseif arch(i386)
            return "i386"
        #elseif arch(powerpc64)
            return "powerpc64"
        #elseif arch(powerpc64le)
            return "powerpc64le"
        #elseif arch(s390x)
            return "s390x"
        #else
            return "unknown"
        #endif
    }

    /// The operating system as reported by Swift. Note that this will report catalyst apps and iOS apps running on
    /// macOS as "iOS". See `platform` for an alternative.
    static var operatingSystem: String {
        #if os(macOS)
            return "macOS"
        #elseif os(visionOS)
            return "visionOS"
        #elseif os(iOS)
            return "iOS"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #else
            return "Unknown Operating System"
        #endif
    }

    /// Based on the operating version reported by swift, but adding some smartness to better detect the actual
    /// platform. Should correctly identify catalyst apps and iOS apps on macOS.
    static var platform: String {
        #if os(macOS)
            return "macOS"
        #elseif os(visionOS)
            return "visionOS"
        #elseif os(iOS)
            #if targetEnvironment(macCatalyst)
                return "macCatalyst"
            #else
                if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
                    return "isiOSAppOnMac"
                }
                return "iOS"
            #endif
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #else
            return "Unknown Platform"
        #endif
    }

    /// The target environment as reported by swift. Either "simulator", "macCatalyst" or "native"
    static var targetEnvironment: String {
        #if targetEnvironment(simulator)
            return "simulator"
        #elseif targetEnvironment(macCatalyst)
            return "macCatalyst"
        #else
            return "native"
        #endif
    }

    /// The locale identifier the app currently runs in. E.g. `en_DE` for an app that does not support German on a device with preferences `[German, English]`, and region Germany.
    static var locale: String {
        return Locale.current.identifier
    }

    /// The region identifier both the user most prefers and also the app is set to. They are always the same because formatters in apps always auto-adjust to the users preferences.
    static var region: String {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            return Locale.current.region?.identifier ?? Locale.current.identifier.components(separatedBy: .init(charactersIn: "-_")).last!
        } else {
            return Locale.current.regionCode ?? Locale.current.identifier.components(separatedBy: .init(charactersIn: "-_")).last!
        }
    }

    /// The language identifier the app is currently running in. This represents the language the system (or the user) has chosen for the app to run in.
    static var appLanguage: String {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            return Locale.current.language.languageCode?.identifier ?? Locale.current.identifier.components(separatedBy: .init(charactersIn: "-_"))[0]
        } else {
            return Locale.current.languageCode ?? Locale.current.identifier.components(separatedBy: .init(charactersIn: "-_"))[0]
        }
    }

    /// The language identifier of the users most preferred language set on the device. Returns also languages the current app is not even localized to.
    static var preferredLanguage: String {
        let preferredLocaleIdentifier = Locale.preferredLanguages.first ?? "zz-ZZ"
        return preferredLocaleIdentifier.components(separatedBy: .init(charactersIn: "-_"))[0]
    }

    /// The color scheme set by the user. Returns `N/A` on unsupported platforms
    @MainActor
    static var colorScheme: String {
        #if os(iOS) || os(tvOS)
        switch UIScreen.main.traitCollection.userInterfaceStyle {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        default:
            return "N/A"
        }
        #elseif os(macOS)
        if #available(macOS 10.14, *) {
            switch NSAppearance.current.name {
            case .aqua:
                return "Light"
            case .darkAqua:
                return "Dark"
            default:
                return "N/A"
            }
        } else {
            return "Light"
        }
        #else
        return "N/A"
        #endif
    }

    /// The user-preferred layout direction (left-to-right or right-to-left) based on the current language/region settings.
    @MainActor
    static var layoutDirection: String {
        #if os(iOS) || os(tvOS)
        return UIApplication.shared.userInterfaceLayoutDirection == .leftToRight ? "leftToRight" : "rightToLeft"
        #elseif os(macOS)
        if let nsApp = NSApp {
            return nsApp.userInterfaceLayoutDirection == .leftToRight ? "leftToRight" : "rightToLeft"
        } else {
            return "N/A"
        }
        #else
        return "N/A"
        #endif
    }

    /// The current devices screen resolution width in points.
    @MainActor
    static var screenResolutionWidth: String {
        #if os(iOS) || os(tvOS)
            return "\(UIScreen.main.bounds.width)"
        #elseif os(watchOS)
            return "\(WKInterfaceDevice.current().screenBounds.width)"
        #elseif os(macOS)
            if let screen = NSScreen.main {
                return "\(screen.frame.width)"
            }
            return "N/A"
        #else
            return "N/A"
        #endif
    }

    /// The current devices screen resolution height in points.
    @MainActor
    static var screenResolutionHeight: String {
        #if os(iOS) || os(tvOS)
            return "\(UIScreen.main.bounds.height)"
        #elseif os(watchOS)
            return "\(WKInterfaceDevice.current().screenBounds.height)"
        #elseif os(macOS)
            if let screen = NSScreen.main {
                return "\(screen.frame.height)"
            }
            return "N/A"
        #else
        return "N/A"
        #endif
    }

    @MainActor
    static var screenScaleFactor: String {
        #if os(iOS) || os(tvOS)
        return "\(UIScreen.main.scale)"
        #elseif os(macOS)
        if let screen = NSScreen.main {
            return "\(screen.backingScaleFactor)"
        }
        return "N/A"
        #else
        return "N/A"
        #endif
    }

    /// The current devices screen orientation. Returns `Fixed` for devices that don't support an orientation change.
    @MainActor
    static var orientation: String {
        #if os(iOS)
            switch UIDevice.current.orientation {
            case .portrait, .portraitUpsideDown:
                return "Portrait"
            case .landscapeLeft, .landscapeRight:
                return "Landscape"
            default:
                return "Unknown"
            }
        #else
            return "Fixed"
        #endif
    }

    /// The devices current time zone in the modern `UTC` format, such as `UTC+1`, or `UTC-3:30`.
    static var timeZone: String {
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        let hours = secondsFromGMT / 3600
        let minutes = abs(secondsFromGMT / 60 % 60)

        let sign = secondsFromGMT >= 0 ? "+" : "-"
        if minutes > 0 {
            return "UTC\(sign)\(hours):\(String(format: "%02d", minutes))"
        } else {
            return "UTC\(sign)\(hours)"
        }
    }
}
