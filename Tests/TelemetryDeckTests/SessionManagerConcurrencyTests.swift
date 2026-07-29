import Foundation
import Testing

@testable import TelemetryDeck

/// Repro for https://github.com/TelemetryDeck/SwiftSDK/issues/236:
///
/// `persistCurrentSessionIfNeeded()` used to mutate `recentSessions` on the caller's thread — the
/// once-per-second `updateSessionDuration` timer, plus the app lifecycle notifications — and then
/// hand that same array to `persistenceQueue` to be JSON-encoded. The encode read the array while
/// the next tick was already mutating it, so the two overlapped.
///
/// ThreadSanitizer reports that as a Swift access race. In the field it also surfaced as a crash or
/// an app hang inside `Array.subscript.modify`, because the pending encode kept the buffer alive and
/// every tick then had to copy the whole array on the main thread before it could mutate it.
///
/// Run with ThreadSanitizer enabled to catch the race itself; without a sanitizer these still assert
/// that the session bookkeeping stays correct while ticks and reads overlap.
///
/// These deliberately avoid `startNewSession()` and `SessionManager.shared`: the former emits an
/// internal signal that requires a globally initialized `TelemetryManager`, and both would leak
/// state into other suites. Driving `updateSessionDuration()` directly exercises the same path.
///
/// Counts are asserted as deltas because `TelemetryDeck.customDefaults` is process-wide: whether it
/// resolves to a real suite depends on whether another suite has initialized the SDK, so a manager
/// may legitimately start with previously persisted sessions.
@Suite(.serialized)
struct SessionManagerConcurrencyTests {
    /// `persistCurrentSessionIfNeeded()` ignores sessions under a second, so a tick only reaches the
    /// array once the session has been running at least that long.
    private static let minimumPersistableSessionDuration: TimeInterval = 1.05

    /// Primes the duration bookkeeping and returns a manager whose next tick will persist.
    private static func makeManagerReadyToPersist() -> SessionManager {
        let manager = SessionManager()
        manager.updateSessionDuration()
        Thread.sleep(forTimeInterval: Self.minimumPersistableSessionDuration)
        return manager
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

    /// Drives ticks the way the run-loop timer does: serially, from a single thread. Each tick
    /// updates the session and encodes it, so tick N+1 overlaps the encode still in flight for N.
    @Test
    func repeatedTicks_updateOneSessionWithoutRacingTheEncode() {
        let manager = Self.makeManagerReadyToPersist()
        let sessionsBefore = manager.totalSessionsCount

        for _ in 0..<200 {
            manager.updateSessionDuration()
        }

        #expect(
            Self.sessionCount(of: manager, settlingAt: sessionsBefore + 1) == sessionsBefore + 1,
            "ticks should keep updating one session, not append per tick"
        )
        #expect(manager.averageSessionSeconds >= 1)
    }

    /// The stats below are read by `DefaultSignalPayload.parameters` on every signal, i.e. from
    /// whichever thread sends it, while the timer keeps updating the same array.
    @Test
    func concurrentStatReads_areConsistentWhileSessionUpdates() async {
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            let manager = Self.makeManagerReadyToPersist()
            let sessionsBefore = manager.totalSessionsCount

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

            #expect(Self.sessionCount(of: manager, settlingAt: sessionsBefore + 1) == sessionsBefore + 1)
        } else {
            print("skipping test on incompatible OS")
        }
    }
}
