import Foundation

/// An event cache that stores events in memory and persists them to a JSON file on disk.
public actor DefaultEventCache: EventCaching {
    private var events: [Event] = []
    private let maxBatchSize = 100
    private let fileURL: URL

    /// Creates a cache that stores events in the default caches directory.
    public init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = cachesURL.appendingPathComponent("telemetrysignalcache.json")
    }

    /// Creates a cache that stores events at the given file URL.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Appends an event to the in-memory store.
    public func add(_ event: Event) {
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
    public func restore() async {
        guard let data = try? Data(contentsOf: fileURL),
            let loaded = try? JSONDecoder.telemetryDecoder.decode([Event].self, from: data)
        else { return }
        try? FileManager.default.removeItem(at: fileURL)
        events = loaded + events
    }
}
