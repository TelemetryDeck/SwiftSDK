@preconcurrency import Foundation

#if canImport(WatchKit)
    import WatchKit
#elseif canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum LifecycleEvent: Sendable {
    case background
    case foreground
    case termination
}

struct LifecycleNotifier: Sendable {
    private final class ObserverBox: @unchecked Sendable {
        var observers: [NSObjectProtocol] = []
    }

    static func events() -> AsyncStream<LifecycleEvent> {
        AsyncStream { continuation in
            let box = ObserverBox()

            #if canImport(WatchKit)
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: WKApplication.didEnterBackgroundNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.background) }
                )
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: WKApplication.willEnterForegroundNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.foreground) }
                )
            #elseif canImport(UIKit) && !os(watchOS)
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.didEnterBackgroundNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.background) }
                )
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.willEnterForegroundNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.foreground) }
                )
            #elseif canImport(AppKit)
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.didResignActiveNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.background) }
                )
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.willBecomeActiveNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.foreground) }
                )
            #endif

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.willTerminateNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(.termination) }
                )
            #endif

            continuation.onTermination = { @Sendable _ in
                for observer in box.observers {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
}
