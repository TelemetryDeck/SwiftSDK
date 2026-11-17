import Foundation

#if os(watchOS)
    import WatchKit
#elseif canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Reports whether the app is currently in the foreground.
enum AppActivity {
    static func isActive() async -> Bool {
        #if os(watchOS)
            await MainActor.run { WKApplication.shared().applicationState != .background }
        #elseif canImport(UIKit)
            if Environment.isAppExtension {
                true
            } else {
                await MainActor.run { UIApplication.shared.applicationState != .background }
            }
        #elseif canImport(AppKit)
            await MainActor.run { NSApp?.isActive ?? true }
        #else
            true
        #endif
    }
}
