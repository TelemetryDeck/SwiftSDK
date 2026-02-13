import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#elseif os(watchOS)
    import WatchKit
#endif

/// Enriches events with system accessibility settings and screen metrics.
public actor AccessibilityProcessor: EventProcessor {
    #if os(iOS) || os(tvOS) || os(visionOS)
        static func directionString(from direction: UIUserInterfaceLayoutDirection) -> String {
            switch direction {
            case .leftToRight: return "leftToRight"
            case .rightToLeft: return "rightToLeft"
            @unknown default: return "Unknown"
            }
        }
    #elseif os(macOS)
        static func directionString(from direction: NSUserInterfaceLayoutDirection) -> String {
            switch direction {
            case .leftToRight: return "leftToRight"
            case .rightToLeft: return "rightToLeft"
            @unknown default: return "Unknown"
            }
        }
    #endif
    private static let cacheLifetime: TimeInterval = 3600

    private var cachedParams: EventParameters?
    private var cacheTimestamp: Date?

    /// Creates an accessibility processor.
    public init() {}

    /// Adds accessibility flags, screen dimensions, colour scheme, and layout direction to the context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context

        let params = await resolvedParams(isTestMode: context.isTestMode ?? false)
        context.addParameters(params)

        return try await next(input, context)
    }

    private func resolvedParams(isTestMode: Bool) async -> EventParameters {
        if !isTestMode,
            let cached = cachedParams,
            let timestamp = cacheTimestamp,
            Date().timeIntervalSince(timestamp) < Self.cacheLifetime
        {
            return cached
        }

        let fresh = await readAccessibilityParams()
        cachedParams = fresh
        cacheTimestamp = Date()
        return fresh
    }

    private func readAccessibilityParams() async -> EventParameters {
        #if os(iOS) || os(tvOS) || os(visionOS)
            return await MainActor.run { () -> EventParameters in
                var result = EventParameters()

                result[DefaultParams.Accessibility.isReduceMotionEnabled] = String(UIAccessibility.isReduceMotionEnabled)
                result[DefaultParams.Accessibility.isBoldTextEnabled] = String(UIAccessibility.isBoldTextEnabled)
                result[DefaultParams.Accessibility.isInvertColorsEnabled] = String(UIAccessibility.isInvertColorsEnabled)
                result[DefaultParams.Accessibility.isDarkerSystemColorsEnabled] = String(UIAccessibility.isDarkerSystemColorsEnabled)
                result[DefaultParams.Accessibility.isReduceTransparencyEnabled] = String(UIAccessibility.isReduceTransparencyEnabled)
                result[DefaultParams.Accessibility.shouldDifferentiateWithoutColor] = String(UIAccessibility.shouldDifferentiateWithoutColor)

                if !Environment.isAppExtension {
                    result[DefaultParams.Accessibility.preferredContentSizeCategory] = UIApplication.shared.preferredContentSizeCategory.rawValue
                        .replacingOccurrences(of: "UICTContentSizeCategory", with: "")
                }

                #if os(iOS)
                    let orientation: String
                    switch UIDevice.current.orientation {
                    case .portrait, .portraitUpsideDown:
                        orientation = "Portrait"
                    case .landscapeLeft, .landscapeRight:
                        orientation = "Landscape"
                    default:
                        orientation = "Unknown"
                    }
                    result[DefaultParams.Device.orientation] = orientation
                #endif

                #if !os(visionOS)
                    let screen = UIScreen.main
                    result[DefaultParams.Device.screenResolutionWidth] = "\(screen.bounds.width)"
                    result[DefaultParams.Device.screenResolutionHeight] = "\(screen.bounds.height)"
                    result[DefaultParams.Device.screenScaleFactor] = "\(screen.scale)"

                    let colorScheme: String
                    switch screen.traitCollection.userInterfaceStyle {
                    case .dark:
                        colorScheme = "Dark"
                    case .light:
                        colorScheme = "Light"
                    default:
                        colorScheme = "N/A"
                    }
                    result[DefaultParams.UserPreference.colorScheme] = colorScheme
                #endif

                if !Environment.isAppExtension {
                    let direction = UIApplication.shared.userInterfaceLayoutDirection
                    result[DefaultParams.UserPreference.layoutDirection] = Self.directionString(from: direction)
                }

                return result
            }

        #elseif os(macOS)
            return await MainActor.run { () -> EventParameters in
                var result = EventParameters()

                result[DefaultParams.Accessibility.isReduceMotionEnabled] = String(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                result[DefaultParams.Accessibility.isInvertColorsEnabled] = String(NSWorkspace.shared.accessibilityDisplayShouldInvertColors)

                let colorScheme: String
                let appearance = NSApp?.effectiveAppearance.name.rawValue.lowercased() ?? ""
                if appearance.contains("dark") {
                    colorScheme = "Dark"
                } else {
                    colorScheme = "Light"
                }
                result[DefaultParams.UserPreference.colorScheme] = colorScheme

                if let layoutDirection = NSApp?.userInterfaceLayoutDirection {
                    result[DefaultParams.UserPreference.layoutDirection] = Self.directionString(from: layoutDirection)
                }

                if let screen = NSScreen.main {
                    result[DefaultParams.Device.screenResolutionWidth] = "\(screen.frame.width)"
                    result[DefaultParams.Device.screenResolutionHeight] = "\(screen.frame.height)"
                    result[DefaultParams.Device.screenScaleFactor] = "\(screen.backingScaleFactor)"
                }

                return result
            }

        #elseif os(watchOS)
            let device = WKInterfaceDevice.current()
            var result = EventParameters()
            result[DefaultParams.Device.screenResolutionWidth] = Double(device.screenBounds.width)
            result[DefaultParams.Device.screenResolutionHeight] = Double(device.screenBounds.height)
            return result

        #else
            return EventParameters()
        #endif
    }
}
