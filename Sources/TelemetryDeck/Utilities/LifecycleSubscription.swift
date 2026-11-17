import Foundation

/// Subscribes to app lifecycle events and forwards background, foreground, and termination transitions to the given handlers.
enum LifecycleSubscription {
    static func start(
        events: AsyncStream<LifecycleEvent> = LifecycleNotifier.events(),
        onBackground: @escaping @Sendable () async -> Void,
        onForeground: @escaping @Sendable () async -> Void,
        onTermination: (@Sendable () async -> Void)? = nil
    ) -> Task<Void, Never> {
        Task {
            for await event in events {
                switch event {
                case .background:
                    await onBackground()
                case .foreground:
                    await onForeground()
                case .termination:
                    await onTermination?()
                }
            }
        }
    }
}
