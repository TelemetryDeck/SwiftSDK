import Foundation
import Testing

@testable import TelemetryDeck

/// Repro for https://github.com/TelemetryDeck/SwiftSDK/issues/236:
///
/// Exercises the once-per-second `updateSessionDuration` tick concurrently with the stat reads
/// (`totalSessionsCount`, `averageSessionSeconds`, `previousSessionSeconds`) that every signal
/// takes off the shared `recentSessions` array.
///
/// The authoritative reproduction is running with ThreadSanitizer enabled:
///
///     swift test --sanitize=thread --filter SessionManagerConcurrencyTests
///
/// Without a sanitizer, these tests only assert that the session bookkeeping stays consistent
/// while ticks and reads overlap; they cannot themselves detect a data race.
///
/// These deliberately avoid `startNewSession()` and `SessionManager.shared`: the former emits an
/// internal signal that requires a globally initialized `TelemetryManager`, and both would leak
/// state into other suites. Driving `updateSessionDuration()` directly exercises the same path.
///
/// Each manager is given its own `UserDefaults` suite, unique per test run, so these runs never
/// read or write the process-wide `TelemetryDeck.customDefaults` suite shared with other test
/// targets. The suite is wiped before use and, after draining the manager's `persistenceQueue` so
/// no write from an earlier tick is still in flight, its in-memory domain is removed again once
/// the test is done; `removePersistentDomain(forName:)` doesn't reliably delete the on-disk backing
/// file even then, so a small stray `.plist` per run in `~/Library/Preferences` is expected and
/// harmless. The suite name is unique per manager, rather than shared across the suite's tests, in
/// case draining ever misses a write: a shared name would let it land in the next test's suite
/// instead of a discarded one.
@Suite(.serialized)
struct SessionManagerConcurrencyTests {
    private static let defaultsSuiteNamePrefix = "SessionManagerConcurrencyTests"

    /// `persistCurrentSessionIfNeeded()` ignores sessions under a second, so a tick only reaches the
    /// array once the session has been running at least that long.
    private static let minimumPersistableSessionDuration: TimeInterval = 1.05

    private static func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "\(Self.defaultsSuiteNamePrefix)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    /// Primes the duration bookkeeping and returns a manager whose next tick will persist, along
    /// with the name of its isolated suite so the caller can wipe it once the test is done.
    private static func makeManagerReadyToPersist() -> (manager: SessionManager, suiteName: String) {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        let manager = SessionManager(defaults: defaults)
        manager.updateSessionDuration()
        Thread.sleep(forTimeInterval: Self.minimumPersistableSessionDuration)
        return (manager, suiteName)
    }

    /// A tick hands the update to a private serial queue, so the count lands a hop later.
    private static func sessionCount(
        of manager: SessionManager,
        settlingAt expected: Int,
        timeout: TimeInterval = 2
    ) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var observed = manager.totalSessionsCount

        while observed != expected, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
            observed = manager.totalSessionsCount
        }

        return observed
    }

    /// Drives ticks the way the run-loop timer does: serially, from a single thread.
    ///
    /// Each tick updates the session and encodes it, so tick N+1 overlaps the encode still in
    /// flight for N.
    @Test
    func repeatedTicks_updateOneSessionWithoutRacingTheEncode() {
        let (manager, suiteName) = Self.makeManagerReadyToPersist()
        defer {
            manager.waitForPendingWrites()
            UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
        }

        for _ in 0..<200 {
            manager.updateSessionDuration()
        }

        #expect(
            Self.sessionCount(of: manager, settlingAt: 1) == 1,
            "ticks should keep updating one session, not append per tick"
        )
        #expect(manager.averageSessionSeconds >= 1)
    }

    /// The stats below are read by `DefaultSignalPayload.parameters` on every signal, i.e. from
    /// whichever thread sends it, while the timer keeps updating the same array.
    @Test
    func concurrentStatReads_areConsistentWhileSessionUpdates() async {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            let (manager, suiteName) = Self.makeManagerReadyToPersist()
            defer {
                manager.waitForPendingWrites()
                UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for _ in 0..<200 {
                        manager.updateSessionDuration()
                    }
                }

                for _ in 0..<20 {
                    group.addTask {
                        _ = manager.averageSessionSeconds
                        _ = manager.totalSessionsCount
                        _ = manager.previousSessionSeconds
                    }
                }

                await group.waitForAll()
            }

            #expect(Self.sessionCount(of: manager, settlingAt: 1) == 1)
        } else {
            print("skipping test on incompatible OS")
        }
    }
}
