@preconcurrency import Foundation

#if canImport(AppKit)
    import AppKit
#endif

struct ScreenChangeNotifier: Sendable {
    private final class ObserverBox: @unchecked Sendable {
        var observers: [NSObjectProtocol] = []
    }

    static func events() -> AsyncStream<Void> {
        AsyncStream { continuation in
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                let box = ObserverBox()
                box.observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.didChangeScreenParametersNotification,
                        object: nil,
                        queue: nil
                    ) { _ in continuation.yield(()) }
                )
                continuation.onTermination = { @Sendable _ in
                    for observer in box.observers {
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            #else
                continuation.finish()
            #endif
        }
    }
}
