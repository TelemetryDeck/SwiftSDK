import Foundation

/// A local cache for signals to be sent to the TelemetryDeck ingestion service
///
/// There is no guarantee that Signals come out in the same order you put them in. This shouldn't matter though,
/// since all Signals automatically get a `receivedAt` property with a date, allowing the server to reorder them
/// correctly.
///
/// Currently the cache is only in-memory. This will probably change in the near future.
internal class SignalCache<T>: @unchecked Sendable where T: Codable {
    internal var logHandler: LogHandler?

    private var cachedSignals: [T] = []
    private let maximumNumberOfSignalsToPopAtOnce = 100

    let queue = DispatchQueue(label: "com.telemetrydeck.SignalCache", attributes: .concurrent)

    /// How many Signals are cached
    func count() -> Int {
        queue.sync(flags: .barrier) {
            self.cachedSignals.count
        }
    }

    /// Insert a Signal into the cache
    func push(_ signal: T) {
        queue.sync(flags: .barrier) {
            self.cachedSignals.append(signal)
        }
    }

    /// Insert a number of Signals into the cache
    func push(_ signals: [T]) {
        queue.sync(flags: .barrier) {
            self.cachedSignals.append(contentsOf: signals)
        }
    }

    /// Remove a number of Signals from the cache and return them
    ///
    /// You should hold on to the signals returned by this function. If the action you are trying to do with them fails
    /// (e.g. sending them to a server) you should reinsert them into the cache with the `push` function.
    func pop() -> [T] {
        var poppedSignals: [T]!

        queue.sync {
            let sliceSize = min(maximumNumberOfSignalsToPopAtOnce, cachedSignals.count)
            poppedSignals = Array(cachedSignals[..<sliceSize])
            cachedSignals.removeFirst(sliceSize)
        }

        return poppedSignals
    }

    private func fileURL() -> URL {
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

    /// Save the entire signal cache to disk asynchronously
    func backupCache() {
        queue.async { [self] in
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

    /// Loads any previous signal cache from disk asynchronously
    init(logHandler: LogHandler?) {
        self.logHandler = logHandler

        queue.async { [weak self] in
            guard let self else { return }
            self.logHandler?.log(message: "Loading Telemetry cache from: \(self.fileURL())")

            if let data = try? Data(contentsOf: self.fileURL()) {
                // Loaded cache file, now delete it to stop it being loaded multiple times
                try? FileManager.default.removeItem(at: self.fileURL())

                // Decode the data into a new cache
                if let signals = try? JSONDecoder().decode([T].self, from: data) {
                    logHandler?.log(message: "Loaded \(signals.count) signals")
                    self.cachedSignals = signals
                }
            }
        }
    }
}
