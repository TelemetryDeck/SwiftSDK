import Foundation
import Testing

@testable import TelemetryDeck

@Suite(.serialized)
struct TrialConversionTrackerTests {
    /// Creates a `TrialConversionTracker` backed by an in-memory `UserDefaults` double, so the test neither
    /// touches the global `TelemetryManager` static nor writes any preferences file to disk.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    private func isolatedTracker() -> (tracker: TrialConversionTracker, defaults: UserDefaults) {
        let defaults = InMemoryUserDefaults()
        let tracker = TrialConversionTracker(userDefaults: { defaults })
        return (tracker, defaults)
    }

    // MARK: - Persistence round-trip

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func saveTrials_loadTrials_roundTripsStoredTrial() {
        let (tracker, _) = isolatedTracker()

        let trial = TrialConversionTracker.StoredTrial(productID: "com.app.pro.monthly", originalTransactionID: 123)
        tracker.saveTrials(["com.app.pro.monthly": trial])

        let loaded = tracker.loadTrials()
        #expect(loaded["com.app.pro.monthly"]?.productID == "com.app.pro.monthly")
        #expect(loaded["com.app.pro.monthly"]?.originalTransactionID == 123)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func saveTrials_withEmptyDictionary_removesStoredData() {
        let (tracker, _) = isolatedTracker()

        let trial = TrialConversionTracker.StoredTrial(productID: "com.app.pro.monthly", originalTransactionID: 123)
        tracker.saveTrials(["com.app.pro.monthly": trial])
        #expect(!tracker.loadTrials().isEmpty)

        tracker.saveTrials([:])
        #expect(tracker.loadTrials().isEmpty)
    }

    // MARK: - Legacy migration

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func migrateLegacyTrialIfNeeded_movesLegacyTrialIntoDictionaryAndClearsLegacyKey() throws {
        let (tracker, defaults) = isolatedTracker()

        let legacyTrial = TrialConversionTracker.StoredTrial(productID: "com.app.legacy", originalTransactionID: 42)
        defaults.set(try JSONEncoder().encode(legacyTrial), forKey: TrialConversionTracker.legacyTrialKey)

        tracker.migrateLegacyTrialIfNeeded()

        #expect(tracker.loadTrials()["com.app.legacy"]?.originalTransactionID == 42)
        #expect(defaults.data(forKey: TrialConversionTracker.legacyTrialKey) == nil)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func migrateLegacyTrialIfNeeded_calledTwice_doesNotDuplicate() throws {
        let (tracker, defaults) = isolatedTracker()

        let legacyTrial = TrialConversionTracker.StoredTrial(productID: "com.app.legacy", originalTransactionID: 42)
        defaults.set(try JSONEncoder().encode(legacyTrial), forKey: TrialConversionTracker.legacyTrialKey)

        tracker.migrateLegacyTrialIfNeeded()
        tracker.migrateLegacyTrialIfNeeded()

        #expect(tracker.loadTrials().count == 1)
    }

    /// A migrated trial that is later claimed (i.e. reported as converted or cancelled) must stay gone: if a
    /// second migration pass resurrected it from a lingering legacy key, the same conversion would be reported
    /// twice.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func migrateLegacyTrialIfNeeded_afterTrialWasClaimed_doesNotResurrectIt() throws {
        let (tracker, defaults) = isolatedTracker()

        let legacyTrial = TrialConversionTracker.StoredTrial(productID: "com.app.legacy", originalTransactionID: 42)
        defaults.set(try JSONEncoder().encode(legacyTrial), forKey: TrialConversionTracker.legacyTrialKey)

        tracker.migrateLegacyTrialIfNeeded()
        #expect(tracker.claimTrial(productID: "com.app.legacy") != nil)

        tracker.migrateLegacyTrialIfNeeded()

        #expect(tracker.loadTrials()["com.app.legacy"] == nil)
    }

    // MARK: - Claiming trials

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func claimTrial_forExistingProduct_removesAndReturnsIt() {
        let (tracker, _) = isolatedTracker()

        let trial = TrialConversionTracker.StoredTrial(productID: "com.app.pro", originalTransactionID: 7)
        tracker.saveTrials(["com.app.pro": trial])

        let claimed = tracker.claimTrial(productID: "com.app.pro")

        #expect(claimed?.originalTransactionID == 7)
        #expect(tracker.loadTrials().isEmpty)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func claimTrial_whenAlreadyClaimedOrUnknown_returnsNil() {
        let (tracker, _) = isolatedTracker()

        let trial = TrialConversionTracker.StoredTrial(productID: "com.app.pro", originalTransactionID: 7)
        tracker.saveTrials(["com.app.pro": trial])

        #expect(tracker.claimTrial(productID: "com.app.pro") != nil)
        #expect(tracker.claimTrial(productID: "com.app.pro") == nil)
        #expect(tracker.claimTrial(productID: "com.app.unknown") == nil)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func claimTrial_calledConcurrently_yieldsExactlyOneWinner() {
        let (tracker, _) = isolatedTracker()

        let trial = TrialConversionTracker.StoredTrial(productID: "com.app.pro", originalTransactionID: 7)
        tracker.saveTrials(["com.app.pro": trial])

        let winnerCount = ClaimWinnerCounter()
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            if tracker.claimTrial(productID: "com.app.pro") != nil {
                winnerCount.increment()
            }
        }

        #expect(winnerCount.value == 1)
    }

    // MARK: - Outcome classification

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_stillOnTrial_whenActiveAndNotExpired() {
        let outcome = TrialConversionTracker.classify(isRevoked: false, isUpgraded: false, isFreeTrial: true, isExpired: false)
        #expect(outcome == .stillOnTrial)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_convertedToPaid_whenNoLongerOnTrial() {
        let outcome = TrialConversionTracker.classify(isRevoked: false, isUpgraded: false, isFreeTrial: false, isExpired: false)
        #expect(outcome == .convertedToPaid)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_convertedToPaid_evenWhenThePaidPeriodHasSinceExpired() {
        let outcome = TrialConversionTracker.classify(isRevoked: false, isUpgraded: false, isFreeTrial: false, isExpired: true)
        #expect(outcome == .convertedToPaid)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_cancelledOrExpired_whenTrialLapsedWithoutConverting() {
        let outcome = TrialConversionTracker.classify(isRevoked: false, isUpgraded: false, isFreeTrial: true, isExpired: true)
        #expect(outcome == .cancelledOrExpired)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_cancelledOrExpired_whenRevoked() {
        let outcome = TrialConversionTracker.classify(isRevoked: true, isUpgraded: false, isFreeTrial: false, isExpired: false)
        #expect(outcome == .cancelledOrExpired)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    @Test
    func classify_cancelledOrExpired_whenUpgraded() {
        let outcome = TrialConversionTracker.classify(isRevoked: false, isUpgraded: true, isFreeTrial: true, isExpired: false)
        #expect(outcome == .cancelledOrExpired)
    }
}

/// A thread-safe counter used to verify that only one of several concurrent `claimTrial` calls succeeds.
private final class ClaimWinnerCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

/// An in-memory `UserDefaults` double that never touches disk, used to isolate `TrialConversionTracker` tests
/// from both real preferences files and the app-wide `TelemetryManager` singleton.
private final class InMemoryUserDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override func data(forKey defaultName: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[defaultName] as? Data
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.lock()
        storage[defaultName] = value
        lock.unlock()
    }

    override func removeObject(forKey defaultName: String) {
        lock.lock()
        storage.removeValue(forKey: defaultName)
        lock.unlock()
    }
}
