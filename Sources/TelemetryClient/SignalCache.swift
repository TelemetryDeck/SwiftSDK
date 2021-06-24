//
//  SignalCache.swift
//
//
//  Created by Daniel Jilg on 22.06.21.
//

import Foundation

/// A local cache for signals to be sent to the AppTelemetry ingestion service
///
/// This class tries to be thread safe, with mutexes being managed in all push and pop functions.
///
/// There is no guarantee that Signals come out in the same order you put them in. This shouldn't matter though,
/// since all Signals automatically get a `receivedAt` property with a date, allowing the server to reorder them
/// correctly.
class SignalCache {
    private var cachedSignals: [SignalPostBody] = []
    private let maximumNumberOfSignalsToPopAtOnce = 10
    var mutex: pthread_mutex_t = pthread_mutex_t()

    /// Insert a Signal into the cache
    func push(_ signal: SignalPostBody) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        cachedSignals.append(signal)
    }
    
    /// Insert a number of Signals into the cache
    func push(_ signals: [SignalPostBody]) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        cachedSignals.append(contentsOf: signals)
    }

    /// Remove a number of Signals from the cache and return them
    ///
    /// You should hold on to the signals returned by this function. If the action you are trying to do with them fails
    /// (e.g. sending them to a server) you should reinsert them into the cache with the `push` function.
    func pop() -> [SignalPostBody] {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let sliceSize = min(maximumNumberOfSignalsToPopAtOnce, cachedSignals.count)
        let poppedSignals = cachedSignals[..<sliceSize]
        cachedSignals.removeFirst(sliceSize)
        
        return Array(poppedSignals)
    }
}
