import Foundation

/// A queue of events waiting to be transmitted, with optional disk persistence.
public protocol EventCaching: Sendable {
    func add(_ event: Event) async
    func add(_ events: [Event]) async
    func pop() async -> [Event]
    func count() async -> Int
    /// Backs up the current in-memory events to disk.
    ///
    /// Called every time the app enters the background, so this can run many times in one process.
    /// The events stay in memory and the transmitter can still send them afterwards.
    func persist() async
    /// Restores events persisted by an earlier process from disk into memory.
    ///
    /// Also called when the app returns to the foreground, possibly in the same process that called
    /// ``persist()``. Implementations must not re-add events that are still in memory, or were already sent.
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
