import StoreKit

/// Responsible for tracking free trial subscriptions and detecting when they convert to paid subscriptions or are canceled.
///
/// This class manages the lifecycle of free trials by:
/// - Storing information about active free trials in UserDefaults
/// - Monitoring StoreKit transactions for trial conversions and cancellations
/// - Sending telemetry signals when a trial converts to a paid subscription
///
/// Outside of this type, two calls are required to get correct trial-to-paid reporting:
/// ```
/// // When a free trial is started
/// TrialConversionTracker.shared.freeTrialStarted(transaction: transaction)
///
/// // Once, at app launch (already done by TelemetryDeck.initialize)
/// TrialConversionTracker.shared.start()
/// ```
///
/// `start()` reconciles any trials that were persisted from a previous launch against their current StoreKit state, which is what lets a trial that converted to paid (or lapsed) while the app was not running still get reported.
/// Once a trial is active, this type automatically starts monitoring live transaction updates and stops doing so when no persisted trial remains.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
final class TrialConversionTracker: @unchecked Sendable {
    struct StoredTrial: Codable {
        let productID: String
        let originalTransactionID: UInt64
    }

    enum TrialOutcome: Equatable { case convertedToPaid, cancelledOrExpired, stillOnTrial }

    static let shared = TrialConversionTracker()

    static let activeTrialsKey = "activeTrials"
    static let legacyTrialKey = "lastTrial"

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.trialtracker.persistence")
    private var transactionUpdateTask: Task<Void, Error>?

    /// Supplies the `UserDefaults` suite this tracker persists trials to.
    ///
    /// Defaults to the app's TelemetryDeck suite; injectable so tests can operate on an isolated suite
    /// without going through `TelemetryDeck.initialize`.
    private let userDefaults: () -> UserDefaults?

    init(userDefaults: @escaping () -> UserDefaults? = { TelemetryDeck.customDefaults }) {
        self.userDefaults = userDefaults
        migrateLegacyTrialIfNeeded()
    }

    /// Reconciles trials persisted from a previous launch against their current StoreKit state.
    ///
    /// A trial that converted to paid, or lapsed, while the app was not running is only detected here, so this
    /// must be called once per launch before any such conversion can be reported. `TelemetryDeck.initialize`
    /// already calls this; nothing else needs to invoke it.
    func start() {
        let trials = currentTrials()
        guard !trials.isEmpty else { return }
        reconcilePersistedTrials(trials)
    }

    /// Call this function only after having validated that the passed transaction is a free trial.
    func freeTrialStarted(transaction: Transaction) {
        let trial = StoredTrial(productID: transaction.productID, originalTransactionID: transaction.originalID)
        persistenceQueue.sync {
            var trials = loadTrials()
            trials[transaction.productID] = trial
            saveTrials(trials)
        }
        startObservingTransactions()
    }

    private static func classify(_ transaction: Transaction, against trial: StoredTrial) -> TrialOutcome? {
        guard transaction.productID == trial.productID,
            transaction.originalID == trial.originalTransactionID
        else { return nil }
        return classify(
            isRevoked: transaction.revocationDate != nil,
            isUpgraded: transaction.isUpgraded,
            isFreeTrial: transaction.isFreeTrial,
            isExpired: transaction.expirationDate?.isInThePast == true
        )
    }

    /// Determines what a trial's matching transaction means for that trial, from plain transaction attributes.
    ///
    /// Revocation and upgrades are checked before the free-trial status, because both mean the transaction no
    /// longer represents an outcome we should report: a revoked/refunded purchase must never be counted as a
    /// conversion, and a transaction superseded by an upgrade no longer reflects this product's own lifecycle.
    /// Only once those are ruled out do we ask whether the transaction is still a free trial. If it is not,
    /// the trial converted to paid, even if that paid period has since expired — expiration only cancels a
    /// trial that never converted.
    static func classify(isRevoked: Bool, isUpgraded: Bool, isFreeTrial: Bool, isExpired: Bool) -> TrialOutcome {
        if isRevoked || isUpgraded {
            return .cancelledOrExpired
        }
        if isFreeTrial {
            return isExpired ? .cancelledOrExpired : .stillOnTrial
        }
        return .convertedToPaid
    }

    /// Claims and reports the outcome of a trial's matching `transaction`, if any.
    ///
    /// - Returns: `true` if the trial is still active and nothing was claimed, `false` once it has been resolved.
    @discardableResult
    private func handleOutcome(_ outcome: TrialOutcome?, for transaction: Transaction) -> Bool {
        switch outcome {
        case .convertedToPaid:
            if claimTrial(productID: transaction.productID) != nil {
                reportConversion(transaction)
            }
            return false
        case .cancelledOrExpired:
            claimTrial(productID: transaction.productID)
            return false
        case .stillOnTrial, nil:
            return true
        }
    }

    private func reconcilePersistedTrials(_ trials: [String: StoredTrial]) {
        Task {
            var anyStillActive = false
            for (productID, trial) in trials {
                guard case .verified(let transaction)? = await Transaction.latest(for: productID) else {
                    anyStillActive = true
                    continue
                }
                if self.handleOutcome(Self.classify(transaction, against: trial), for: transaction) {
                    anyStillActive = true
                }
            }
            if anyStillActive {
                self.startObservingTransactions()
            }
        }
    }

    private func reportConversion(_ transaction: Transaction) {
        TelemetryDeck.internalSignal(
            "TelemetryDeck.Purchase.convertedFromTrial",
            parameters: transaction.purchaseParameters(),
            floatValue: transaction.priceInUSD()
        )
    }

    private func startObservingTransactions() {
        persistenceQueue.sync {
            guard transactionUpdateTask == nil else { return }
            transactionUpdateTask = Task {
                for await verificationResult in Transaction.updates {
                    guard case .verified(let transaction) = verificationResult else { continue }
                    let trials = self.currentTrials()
                    guard let trial = trials[transaction.productID] else { continue }
                    self.handleOutcome(Self.classify(transaction, against: trial), for: transaction)
                }
            }
        }
    }

    private func stopObservingTransactions() {
        persistenceQueue.sync {
            transactionUpdateTask?.cancel()
            transactionUpdateTask = nil
        }
    }

    @discardableResult
    func claimTrial(productID: String) -> StoredTrial? {
        let claim: (trial: StoredTrial?, remaining: [String: StoredTrial]) = persistenceQueue.sync {
            var trials = loadTrials()
            let claimed = trials.removeValue(forKey: productID)
            if claimed != nil {
                saveTrials(trials)
            }
            return (claimed, trials)
        }
        if claim.trial != nil, claim.remaining.isEmpty {
            stopObservingTransactions()
        }
        return claim.trial
    }

    func migrateLegacyTrialIfNeeded() {
        persistenceQueue.sync {
            guard let data = userDefaults()?.data(forKey: Self.legacyTrialKey),
                let trial = try? JSONDecoder().decode(StoredTrial.self, from: data)
            else { return }
            var trials = loadTrials()
            if trials[trial.productID] == nil {
                trials[trial.productID] = trial
                saveTrials(trials)
            }
            userDefaults()?.removeObject(forKey: Self.legacyTrialKey)
        }
    }

    private func currentTrials() -> [String: StoredTrial] {
        persistenceQueue.sync { loadTrials() }
    }

    func loadTrials() -> [String: StoredTrial] {
        guard let data = userDefaults()?.data(forKey: Self.activeTrialsKey),
            let trials = try? JSONDecoder().decode([String: StoredTrial].self, from: data)
        else { return [:] }
        return trials
    }

    func saveTrials(_ trials: [String: StoredTrial]) {
        if trials.isEmpty {
            userDefaults()?.removeObject(forKey: Self.activeTrialsKey)
        } else if let data = try? JSONEncoder().encode(trials) {
            userDefaults()?.set(data, forKey: Self.activeTrialsKey)
        }
    }
}

// Convenience extension to check trial status
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension Transaction {
    var isFreeTrial: Bool {
        if #available(iOS 17.2, macOS 14.2, tvOS 17.2, visionOS 1.1, watchOS 10.2, *) {
            return self.offer?.type == .introductory && self.offer?.paymentMode == .freeTrial
        } else {
            return self.offerType == .introductory && self.offerPaymentModeStringRepresentation == "FREE_TRIAL"
        }
    }
}

extension Date {
    var isInThePast: Bool {
        self.timeIntervalSinceNow < 0
    }
}
