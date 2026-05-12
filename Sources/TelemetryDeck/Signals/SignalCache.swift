import Foundation

/// A local cache for signals to be sent to the TelemetryDeck ingestion service
///
/// There is no guarantee that Signals come out in the same order you put them in. This shouldn't matter though,
/// since all Signals automatically get a `receivedAt` property with a date, allowing the server to reorder them
/// correctly.
///
/// The cache persists signals to disk via `backupCache()` and automatically restores them in `init`.
/// Signals in excess of `cacheLimit` are dropped from the front (oldest first) to keep memory and disk usage bounded.
internal class SignalCache<T>: @unchecked Sendable where T: Codable {
    internal var logHandler: LogHandler?

    private var cachedSignals: [T] = []
    private let maximumNumberOfSignalsToPopAtOnce = 100
    private let cacheLimit: Int
    private let cacheFileURL: URL?

    let queue = DispatchQueue(label: "com.telemetrydeck.SignalCache", attributes: .concurrent)

    /// How many Signals are cached
    func count() -> Int {
        queue.sync {
            self.cachedSignals.count
        }
    }

    /// Insert a Signal into the cache
    func push(_ signal: T) {
        queue.sync(flags: .barrier) {
            self.cachedSignals.append(signal)
            self.trimToCacheLimitLocked()
        }
    }

    /// Insert a number of Signals into the cache
    func push(_ signals: [T]) {
        queue.sync(flags: .barrier) {
            self.cachedSignals.append(contentsOf: signals)
            self.trimToCacheLimitLocked()
        }
    }

    private func trimToCacheLimitLocked() {
        if cachedSignals.count > cacheLimit {
            cachedSignals.removeFirst(cachedSignals.count - cacheLimit)
        }
    }

    /// Remove a number of Signals from the cache and return them
    ///
    /// You should hold on to the signals returned by this function. If the action you are trying to do with them fails
    /// (e.g. sending them to a server) you should reinsert them into the cache with the `push` function.
    func pop() -> [T] {
        queue.sync(flags: .barrier) {
            let sliceSize = min(maximumNumberOfSignalsToPopAtOnce, cachedSignals.count)
            let poppedSignals = Array(cachedSignals[..<sliceSize])
            cachedSignals.removeFirst(sliceSize)
            return poppedSignals
        }
    }

    private func fileURL() -> URL {
        if let cacheFileURL {
            return cacheFileURL
        }

        // swiftlint:disable force_try
        let cacheFolderURL = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        // swiftlint:enable force_try

        return cacheFolderURL.appendingPathComponent("telemetrysignalcache")
    }

    /// Save the entire signal cache to disk
    func backupCache() {
        queue.sync {
            if let data = try? JSONEncoder().encode(self.cachedSignals) {
                do {
                    try data.write(to: fileURL())
                    logHandler?.log(message: "Saved Telemetry cache \(data) of \(self.cachedSignals.count) signals")
                    // After saving the cache, we need to clear our local cache otherwise
                    // it could get merged with the cache read back from disk later if
                    // it's still in memory
                    self.cachedSignals = []
                } catch {
                    logHandler?.log(.error, message: "Error saving Telemetry cache")
                }
            }
        }
    }

    /// Loads any previous signal cache from disk
    init(logHandler: LogHandler?, cacheLimit: Int = 10_000, fileURL: URL? = nil) {
        self.logHandler = logHandler
        self.cacheLimit = cacheLimit
        self.cacheFileURL = fileURL

        queue.sync {
            logHandler?.log(message: "Loading Telemetry cache from: \(self.fileURL())")

            if let data = try? Data(contentsOf: self.fileURL()) {
                // Loaded cache file, now delete it to stop it being loaded multiple times
                try? FileManager.default.removeItem(at: self.fileURL())

                // Decode the data into a new cache
                if let signals = try? JSONDecoder().decode([T].self, from: data) {
                    logHandler?.log(message: "Loaded \(signals.count) signals")
                    self.cachedSignals = Array(signals.suffix(cacheLimit))
                }
            }
        }
    }
}
