import Foundation

/// An event cache that stores events in memory and persists them to a JSON file on disk.
public actor DefaultEventCache: EventCaching {
    private var events: [Event] = []
    private let maxBatchSize = 100
    private let fileURL: URL
    private let cacheLimit: Int

    /// Creates a cache that stores events in the default caches directory.
    public init(cacheLimit: Int = 10_000) {
        assert(cacheLimit > 0, "cacheLimit must be greater than zero")
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = cachesURL.appendingPathComponent("telemetrysignalcache.json")
        self.cacheLimit = cacheLimit
    }

    /// Creates a cache that stores events at the given file URL.
    public init(fileURL: URL, cacheLimit: Int = 10_000) {
        assert(cacheLimit > 0, "cacheLimit must be greater than zero")
        self.fileURL = fileURL
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

    /// Returns the number of events currently cached in memory.
    public func count() -> Int {
        events.count
    }

    /// Encodes and writes the current events to the cache file on disk.
    public func persist() async {
        guard let data = try? JSONEncoder.telemetryEncoder.encode(events) else { return }
        try? data.write(to: fileURL)
    }

    /// Reads previously persisted events from disk and prepends them to the in-memory queue.
    ///
    /// Loaded events are older than in-memory events and occupy the front of the queue under FIFO.
    /// If the combined count exceeds `cacheLimit`, the oldest loaded events are trimmed first.
    public func restore() async {
        guard let data = try? Data(contentsOf: fileURL),
            let loaded = try? JSONDecoder.telemetryDecoder.decode([Event].self, from: data)
        else { return }
        try? FileManager.default.removeItem(at: fileURL)
        let combined = loaded.count + events.count
        if combined > cacheLimit {
            let excess = combined - cacheLimit
            let trimmedLoaded = Array(loaded.dropFirst(min(excess, loaded.count)))
            events = trimmedLoaded + events
        } else {
            events = loaded + events
        }
    }
}
