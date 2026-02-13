import Foundation

/// A non-persistent event cache that stores events only in memory; suitable for testing.
public actor InMemoryEventCache: EventCaching {
    private var events: [Event] = []

    /// Creates an empty in-memory event cache.
    public init() {}

    /// Appends an event to the in-memory store.
    public func add(_ event: Event) {
        events.append(event)
    }

    /// Removes and returns all cached events.
    public func pop() -> [Event] {
        let all = events
        events.removeAll()
        return all
    }

    /// Returns the number of events currently in the cache.
    public func count() -> Int {
        events.count
    }
}
