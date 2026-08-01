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
    private let dateProvider: DateProvider
    private var screenChangeTask: Task<Void, Never>?

    /// Creates an accessibility processor.
    public init() {
        self.dateProvider = .system
    }

    init(dateProvider: DateProvider) {
        self.dateProvider = dateProvider
    }

    var hasCachedParamsForTesting: Bool { cachedParams != nil }

    /// Registers a screen-change observer so the cache is invalidated when displays are connected, disconnected, or reconfigured.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        screenChangeTask = Task { [weak self] in
            for await _ in ScreenChangeNotifier.events() {
                await self?.invalidateCache()
            }
        }
    }

    /// Cancels the screen-change observer registered by ``start(storage:logger:emitter:)``.
    public func stop() async {
        screenChangeTask?.cancel()
        screenChangeTask = nil
    }

    private func invalidateCache() {
        cachedParams = nil
        cacheTimestamp = nil
    }

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
            dateProvider.now().timeIntervalSince(timestamp) < Self.cacheLifetime
        {
            return cached
        }

        let fresh = await readAccessibilityParams()
        cachedParams = fresh
        cacheTimestamp = dateProvider.now()
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

                if let screen = NSScreen.screens.first {
                    result[DefaultParams.Device.screenScaleFactor] = "\(screen.backingScaleFactor)"
                }

                return result
            }

        #elseif os(watchOS)
            return EventParameters()

        #else
            return EventParameters()
        #endif
    }
}
