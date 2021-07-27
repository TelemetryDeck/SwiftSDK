import Foundation

/// A local cache for signals to be sent to the AppTelemetry ingestion service
///
/// There is no guarantee that Signals come out in the same order you put them in. This shouldn't matter though,
/// since all Signals automatically get a `receivedAt` property with a date, allowing the server to reorder them
/// correctly.
///
/// Currently the cache is only in-memory. This will probably change in the near future.
internal class SignalCache<T> where T: Codable {
    public var showDebugLogs: Bool = false
    
    private var cachedSignals: [T] = []
    private let maximumNumberOfSignalsToPopAtOnce = 100
    
    let queue = DispatchQueue(label: "apptelemetry-signal-cache", attributes: .concurrent)
    
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
        let cacheFolderURL = try! FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        return cacheFolderURL.appendingPathComponent("telemetrysignalcache")
    }
    
    /// Save the entire signal cache to disk
    func backupCache() {
        queue.sync {
            if let data = try? JSONEncoder().encode(self.cachedSignals) {
                do {
                    try data.write(to: fileURL())
                    if showDebugLogs {
                        print("Saved Telemetry cache \(data) of \(self.cachedSignals.count) signals")
                    }
                    // After saving the cache, we need to clear our local cache otherwise
                    // it could get merged with the cache read back from disk later if
                    // it's still in memory
                    self.cachedSignals = []
                } catch {
                    print("Error saving Telemetry cache")
                }
            }
        }
    }
    
    /// Loads any previous signal cache from disk
    init(showDebugLogs: Bool) {
        self.showDebugLogs = showDebugLogs
        
        queue.sync {
            if showDebugLogs {
                print("Loading Telemetry cache from: \(fileURL())")
            }
            if let data = try? Data(contentsOf: fileURL()) {
                // Loaded cache file, now delete it to stop it being loaded multiple times
                try? FileManager.default.removeItem(at: fileURL())
                
                // Decode the data into a new cache
                if let signals = try? JSONDecoder().decode([T].self, from: data) {
                    if showDebugLogs {
                        print("Loaded \(signals.count) signals")
                    }
                    self.cachedSignals = signals
                }
            }
        }
    }
}
