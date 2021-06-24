//
//  SignalCache.swift
//
//
//  Created by Daniel Jilg on 22.06.21.
//

import Foundation

/// A local cache for signals to be sent to the AppTelemetry ingestion service
///
/// There is no guarantee that Signals come out in the same order you put them in. This shouldn't matter though,
/// since all Signals automatically get a `receivedAt` property with a date, allowing the server to reorder them
/// correctly.
///
/// Currently the cache is only in-memory. This will probably change in the near future.
class SignalCache {
    private var cachedSignals: [SignalPostBody] = []
    private let maximumNumberOfSignalsToPopAtOnce = 100
    let queue = DispatchQueue(label: "apptelemetry-signal-cache", attributes: .concurrent)

    /// Insert a Signal into the cache
    func push(_ signal: SignalPostBody) {
        queue.async(flags: .barrier) {
            self.cachedSignals.append(signal)
        }
    }

    /// Insert a number of Signals into the cache
    func push(_ signals: [SignalPostBody]) {
        queue.async(flags: .barrier) {
            self.cachedSignals.append(contentsOf: signals)
        }
    }

    /// Remove a number of Signals from the cache and return them
    ///
    /// You should hold on to the signals returned by this function. If the action you are trying to do with them fails
    /// (e.g. sending them to a server) you should reinsert them into the cache with the `push` function.
    func pop() -> [SignalPostBody] {
        var poppedSignals: [SignalPostBody]!
        
        queue.sync {
            let sliceSize = min(maximumNumberOfSignalsToPopAtOnce, cachedSignals.count)
            poppedSignals = Array(cachedSignals[..<sliceSize])
            cachedSignals.removeFirst(sliceSize)
        }
        
        return poppedSignals
    }
}
