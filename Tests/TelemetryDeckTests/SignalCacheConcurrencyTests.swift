import Foundation
import Testing

@testable import TelemetryDeck

struct SignalCacheConcurrencyTests {

    /// Repro for https://github.com/TelemetryDeck/SwiftSDK/issues/265:
    ///
    /// count() with barrier blocks because it waits for ALL pending GCD operations.
    ///
    /// The bug: When count() uses `.barrier`, it must wait for all prior async blocks
    /// to complete before executing. If those blocks do work before calling push(),
    /// count() is blocked for their entire duration.
    ///
    /// This test queues async blocks with artificial delays to create pending work,
    /// then immediately calls count() to measure blocking.
    @Test
    func count_barrierCausesMainThreadBlock() {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            let cache = SignalCache<SignalPostBody>(logHandler: nil)
            let stressQueue = DispatchQueue(label: "com.telemetrydeck.stressdaqueue", attributes: .concurrent)

            // Queue 50 operations that each take 2ms BEFORE reaching push()
            // With barrier bug: count() waits for ALL of these (~100ms total)
            // With fix: count() returns immediately (~0ms)
            for i in 0..<50 {
                stressQueue.async {
                    Thread.sleep(forTimeInterval: 0.002)
                    cache.push(Self.makeSignal(id: "\(i)"))
                }
            }

            // Immediately call count() - this is what the timer callback does
            let start = CFAbsoluteTimeGetCurrent()
            _ = cache.count()
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            // With barrier bug: ~100ms (50 * 2ms serialized wait)
            // With fix (no barrier): < 10ms (just reads array.count)
            #expect(elapsed < 0.010, "count() blocked for \(elapsed)s - barrier flag causing contention")
        } else {
            print("skipping test on incompatible OS")
        }
    }

    /// Validates thread safety of concurrent push and pop operations.
    /// After fix, pop() uses barrier flag to ensure exclusive access during mutation.
    @Test
    func concurrentPushAndPop_maintainsDataIntegrity() async {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            let cache = SignalCache<SignalPostBody>(logHandler: nil)
            let pushCount = 500

            await withTaskGroup(of: Void.self) { group in
                // Concurrent pushes
                for i in 0..<pushCount {
                    group.addTask {
                        cache.push(Self.makeSignal(id: "\(i)"))
                    }
                }

                // Concurrent pops (some will return empty arrays, that's fine)
                for _ in 0..<50 {
                    group.addTask {
                        _ = cache.pop()
                    }
                }

                await group.waitForAll()
            }

            // Drain remaining signals
            var totalPopped = 0
            var batch = cache.pop()
            while !batch.isEmpty {
                totalPopped += batch.count
                batch = cache.pop()
            }

            // We should have popped some signals (exact count varies due to concurrency)
            // The key assertion is that we don't crash or corrupt data
            #expect(cache.count() == 0, "Cache should be empty after draining")
        } else {
            print("skipping test on incompatible OS")
        }
    }

    /// Validates that high contention on count() completes in reasonable time.
    /// Pre-fix: barrier on count() causes blocking. Post-fix: reads are concurrent.
    /// This is probably a "flaky" test since we rely on timing
    @Test
    func count_performsUnderHighContention() async {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            let cache = SignalCache<SignalPostBody>(logHandler: nil)

            // Pre-populate cache
            for i in 0..<100 {
                cache.push(Self.makeSignal(id: "\(i)"))
            }

            let startTime = ContinuousClock.now

            await withTaskGroup(of: Void.self) { group in
                // Many concurrent count() calls - should NOT serialize
                for _ in 0..<1000 {
                    group.addTask {
                        _ = cache.count()
                    }
                }
                await group.waitForAll()
            }

            let elapsed = ContinuousClock.now - startTime

            // 1000 concurrent reads should complete quickly (< 1 second)
            // With barrier bug, this would take much longer due to serialization
            #expect(elapsed < .seconds(5), "Concurrent count() calls should complete quickly")
        } else {
            print("skipping test on incompatible OS")
        }
    }

    /// Validates pop() correctly handles concurrent access without data races.
    /// Without barrier on pop(), concurrent calls can corrupt the array.
    /// Run multiple iterations to increase probability of catching race condition.
    @Test
    func pop_isThreadSafe() async {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            for iteration in 0..<10 {
                let cache = SignalCache<SignalPostBody>(logHandler: nil)
                let signalCount = 200

                for i in 0..<signalCount {
                    cache.push(Self.makeSignal(id: "\(iteration)_\(i)"))
                }

                let allPopped = await withTaskGroup(of: [SignalPostBody].self, returning: [[SignalPostBody]].self) { group in
                    for _ in 0..<20 {
                        group.addTask {
                            cache.pop()
                        }
                    }

                    var collected: [[SignalPostBody]] = []
                    for await batch in group {
                        collected.append(batch)
                    }
                    return collected
                }

                let totalPopped = allPopped.flatMap { $0 }.count
                let remaining = cache.count()

                #expect(
                    totalPopped + remaining == signalCount,
                    "Iteration \(iteration): Total signals (popped + remaining) should equal original count"
                )
            }
        } else {
            print("skipping test on incompatible OS")
        }

    }

    // MARK: - Helpers

    private static func makeSignal(id: String) -> SignalPostBody {
        SignalPostBody(
            receivedAt: Date(),
            appID: UUID().uuidString,
            clientUser: id,
            sessionID: id,
            type: "test",
            floatValue: nil,
            payload: [:],
            isTestMode: "true"
        )
    }
}
