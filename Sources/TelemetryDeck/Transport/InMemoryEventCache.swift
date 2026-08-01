import Foundation

/// A non-persistent event cache that stores events only in memory; suitable for in-memory-only production use and testing.
public actor InMemoryEventCache: EventCaching {
    private var events: [Event] = []
    private let maxBatchSize = 100
    private let cacheLimit: Int

    /// Creates an empty in-memory event cache with an optional FIFO cap.
    public init(cacheLimit: Int = .max) {
        assert(cacheLimit > 0, "cacheLimit must be greater than zero")
        self.cacheLimit = cacheLimit
    }

    /// Appends an event to the in-memory store, evicting the oldest events when the cache limit is reached.
    public func add(_ event: Event) {
        if events.count >= cacheLimit {
            let overflow = events.count - cacheLimit + 1
            events.removeFirst(overflow)
        }
        events.append(event)
    }

    /// Removes and returns up to `maxBatchSize` events from the front of the queue.
    public func pop() -> [Event] {
        let batch = Array(events.prefix(maxBatchSize))
        events.removeFirst(min(maxBatchSize, events.count))
        return batch
    }

    /// Returns the number of events currently in the cache.
    public func count() -> Int {
        events.count
    }
}
