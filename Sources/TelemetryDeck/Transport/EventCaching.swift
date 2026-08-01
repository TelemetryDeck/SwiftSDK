import Foundation

/// A queue of events waiting to be transmitted, with optional disk persistence.
public protocol EventCaching: Sendable {
    func add(_ event: Event) async
    func add(_ events: [Event]) async
    func pop() async -> [Event]
    func count() async -> Int
    /// Persists the current in-memory events to disk.
    func persist() async
    /// Restores previously persisted events from disk into memory.
    func restore() async
}

extension EventCaching {
    /// Adds a sequence of events one by one.
    public func add(_ events: [Event]) async {
        for event in events {
            await add(event)
        }
    }

    /// Default no-op implementation.
    public func persist() async {}
    /// Default no-op implementation.
    public func restore() async {}
}
