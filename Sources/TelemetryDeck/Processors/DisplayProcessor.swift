import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#elseif os(watchOS)
    import WatchKit
#endif

/// Enriches events with screen dimensions for connected displays.
public actor DisplayProcessor: EventProcessor {
    private static let cacheLifetime: TimeInterval = 3600

    private var cachedParams: EventParameters?
    private var cacheTimestamp: Date?
    private let dateProvider: DateProvider

    /// Creates a display processor.
    public init() {
        self.dateProvider = .system
    }

    init(dateProvider: DateProvider) {
        self.dateProvider = dateProvider
    }

    /// Add screen information to the event.
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

        let fresh = await readScreenParams()
        cachedParams = fresh
        cacheTimestamp = dateProvider.now()
        return fresh
    }

    private func readScreenParams() async -> EventParameters {
        #if os(iOS) || os(tvOS)
            return await MainActor.run { () -> EventParameters in
                var result = EventParameters()

                let allScreens = UIScreen.screens
                let primary = resolvedPrimaryScreen()

                let primaryWidth = Int(primary.nativeBounds.width.rounded())
                let primaryHeight = Int(primary.nativeBounds.height.rounded())
                result[DefaultParams.Screens.primaryWidth] = primaryWidth
                result[DefaultParams.Screens.primaryHeight] = primaryHeight
                result[DefaultParams.Screens.primaryResolution] = resolutionString(primaryWidth, primaryHeight)

                let allWidths = allScreens.map { Int($0.nativeBounds.width.rounded()) }
                let allHeights = allScreens.map { Int($0.nativeBounds.height.rounded()) }
                result[DefaultParams.Screens.allWidth] = allWidths
                result[DefaultParams.Screens.allHeight] = allHeights
                result[DefaultParams.Screens.allResolution] = zip(allWidths, allHeights).map { resolutionString($0, $1) }
                result[DefaultParams.Screens.allCount] = allScreens.count

                result[DefaultParams.Device.screenResolutionWidth] = "\(primary.bounds.width)"
                result[DefaultParams.Device.screenResolutionHeight] = "\(primary.bounds.height)"

                return result
            }

        #elseif os(macOS)
            return await MainActor.run { () -> EventParameters in
                var result = EventParameters()

                let allScreens = NSScreen.screens
                guard let primary = allScreens.first else { return result }

                let primaryPixels = pixelSize(frame: primary.frame, scale: primary.backingScaleFactor)
                result[DefaultParams.Screens.primaryWidth] = primaryPixels.widthPx
                result[DefaultParams.Screens.primaryHeight] = primaryPixels.heightPx
                result[DefaultParams.Screens.primaryResolution] = resolutionString(primaryPixels.widthPx, primaryPixels.heightPx)

                let allPixels = allScreens.map { pixelSize(frame: $0.frame, scale: $0.backingScaleFactor) }
                result[DefaultParams.Screens.allWidth] = allPixels.map(\.widthPx)
                result[DefaultParams.Screens.allHeight] = allPixels.map(\.heightPx)
                result[DefaultParams.Screens.allResolution] = allPixels.map { resolutionString($0.widthPx, $0.heightPx) }
                result[DefaultParams.Screens.allCount] = allScreens.count

                result[DefaultParams.Device.screenResolutionWidth] = "\(primary.frame.width)"
                result[DefaultParams.Device.screenResolutionHeight] = "\(primary.frame.height)"

                return result
            }

        #elseif os(watchOS)
            let device = WKInterfaceDevice.current()
            let bounds = device.screenBounds
            let scale = device.screenScale
            let widthPx = pixelSize(dimension: bounds.width, scale: scale)
            let heightPx = pixelSize(dimension: bounds.height, scale: scale)

            var result = EventParameters()
            result[DefaultParams.Screens.primaryWidth] = widthPx
            result[DefaultParams.Screens.primaryHeight] = heightPx
            result[DefaultParams.Screens.primaryResolution] = resolutionString(widthPx, heightPx)
            result[DefaultParams.Screens.allWidth] = [widthPx]
            result[DefaultParams.Screens.allHeight] = [heightPx]
            result[DefaultParams.Screens.allResolution] = [resolutionString(widthPx, heightPx)]
            result[DefaultParams.Screens.allCount] = 1
            result[DefaultParams.Device.screenResolutionWidth] = Double(bounds.width)
            result[DefaultParams.Device.screenResolutionHeight] = Double(bounds.height)
            return result

        #else
            return EventParameters()
        #endif
    }

    private nonisolated func resolutionString(_ width: Int, _ height: Int) -> String {
        "\(width),\(height)"
    }

    #if os(iOS) || os(tvOS)
        @MainActor
        private func resolvedPrimaryScreen() -> UIScreen {
            if !Environment.isAppExtension {
                let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                let activeScene = windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first
                if let screen = activeScene?.screen {
                    return screen
                }
            }
            return UIScreen.main
        }
    #elseif os(macOS)
        @MainActor
        private func pixelSize(frame: CGRect, scale: CGFloat) -> (widthPx: Int, heightPx: Int) {
            (Int(round(frame.width * scale)), Int(round(frame.height * scale)))
        }
    #elseif os(watchOS)
        private func pixelSize(dimension: CGFloat, scale: CGFloat) -> Int {
            Int(round(dimension * scale))
        }
    #endif
}
