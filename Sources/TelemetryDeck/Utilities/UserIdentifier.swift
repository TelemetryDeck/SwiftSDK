import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#elseif os(watchOS)
    import WatchKit
#endif

enum UserIdentifier {
    static func resolveDefaultUserIdentifier(storage: any ProcessorStorage) async -> String {
        #if os(iOS) || os(tvOS) || os(visionOS)
            if let vendorID = await MainActor.run(body: { UIDevice.current.identifierForVendor?.uuidString }) {
                return vendorID
            }
            return fallbackIdentifier
        #elseif os(watchOS)
            if let vendorID = await MainActor.run(body: { WKInterfaceDevice.current().identifierForVendor?.uuidString }) {
                return vendorID
            }
            return fallbackIdentifier
        #elseif os(macOS)
            if let stored = await storage.string(forKey: "defaultUserIdentifier") {
                return stored
            }
            let newID = UUID().uuidString
            await storage.set(newID, forKey: "defaultUserIdentifier")
            return newID
        #else
            return fallbackIdentifier
        #endif
    }

    private static var fallbackIdentifier: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        #if os(macOS)
            let platform = "macOS"
        #elseif os(visionOS)
            let platform = "visionOS"
        #elseif os(iOS)
            let platform = "iOS"
        #elseif os(watchOS)
            let platform = "watchOS"
        #elseif os(tvOS)
            let platform = "tvOS"
        #else
            let platform = "Unknown"
        #endif
        return "unknown user \(platform) \(version.majorVersion).\(version.minorVersion).\(version.patchVersion) \(buildNumber)"
    }
}
