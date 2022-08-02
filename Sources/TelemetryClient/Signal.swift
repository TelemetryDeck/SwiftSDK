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

internal struct SignalPostBody: Codable, Equatable {
    /// When was this signal generated
    let receivedAt: Date

    /// The App ID of this signal
    let appID: UUID

    /// A user identifier. This should be hashed on the client, and will be hashed + salted again
    /// on the server to break any connection to personally identifiable data.
    let clientUser: String

    /// A randomly generated session identifier. Should be the same over the course of the session
    let sessionID: String

    /// A type name for this signal that describes the event that triggered the signal
    let type: String

    /// Tags in the form "key:value" to attach to the signal
    let payload: [String]

    /// If "true", mark the signal as a testing signal and only show it in a dedicated test mode UI
    let isTestMode: String
}

internal struct SignalPayload: Codable {
    var platform: String = Self.platform
    var systemVersion: String = Self.systemVersion
    var majorSystemVersion: String = Self.majorSystemVersion
    var majorMinorSystemVersion: String = Self.majorMinorSystemVersion
    var appVersion: String = Self.appVersion
    var buildNumber: String = Self.buildNumber
    var isSimulator: String = "\(Self.isSimulator)"
    var isDebug: String = "\(Self.isDebug)"
    var isTestFlight: String = "\(Self.isTestFlight)"
    var isAppStore: String = "\(Self.isAppStore)"
    var modelName: String = Self.modelName
    var architecture: String = Self.architecture
    var operatingSystem: String = Self.operatingSystem
    var targetEnvironment: String = Self.targetEnvironment
    var locale: String = Self.locale
    var telemetryClientVersion: String = TelemetryClientVersion

    let additionalPayload: [String: String]
}

extension SignalPayload {
    /// Converts the `additionalPayload` to a `[String: String]` dictionary
    func toDictionary() -> [String: String] {
        // We need to convert the additionalPayload into new key/value pairs
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            // Create a Dictionary
            let jsonData = try encoder.encode(self)
            var dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            // Remove the additionalPayload sub dictionary
            dict?.removeValue(forKey: "additionalPayload")
            // Add the additionalPayload as new key/value pairs
            return dict?.merging(additionalPayload, uniquingKeysWith: { _, last in last }) as? [String: String] ?? [:]
        } catch {
            return [:]
        }
    }

    func toMultiValueDimension() -> [String] {
        return toDictionary().map { key, value in key.replacingOccurrences(of: ":", with: "_") + ":" + value }
    }
}

// MARK: - Helpers

extension SignalPayload {
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
        #endif

        #if TARGET_OS_OSX || TARGET_OS_MACCATALYST
            return false
        #endif

        #if targetEnvironment(simulator)
            return false
        #else

            // During development, this line will through a warning "Code after 'return' will never be executed"
            // However, you should ignore that warning.
            if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, appStoreReceiptURL.lastPathComponent == "sandboxReceipt" {
                return true
            } else {
                return false
            }

        #endif
    }

    /// The operating system and its version
    static var systemVersion: String {
        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)"
    }

    /// The major system version, i.e. iOS 15
    static var majorSystemVersion: String {
        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }

    /// The major system version, i.e. iOS 15
    static var majorMinorSystemVersion: String {
        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)"
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

    /// The locale identifier
    static var locale: String {
        return Locale.current.identifier
    }
}
