import StoreKit

/// Responsible for tracking free trial subscriptions and detecting when they convert to paid subscriptions or are canceled.
///
/// This class manages the lifecycle of free trials by:
/// - Storing information about active free trials in UserDefaults
/// - Monitoring StoreKit transactions for trial conversions and cancellations
/// - Sending telemetry signals when a trial converts to a paid subscription
///
/// The API call needed to make outside it is this:
/// ```
/// // When a free trial is started
/// TrialConversionTracker.shared.freeTrialStarted(transaction: transaction)
/// ```
///
/// This type automatically starts monitoring transactions during a free trial phase and stops doing so when no longer needed.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
final class TrialConversionTracker: @unchecked Sendable {
    private struct StoredTrial: Codable {
        let productID: String
        let originalTransactionID: UInt64
    }

    private enum TrialOutcome { case convertedToPaid, cancelledOrExpired, stillOnTrial }

    static let shared = TrialConversionTracker()

    private static let activeTrialsKey = "activeTrials"
    private static let legacyTrialKey = "lastTrial"

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.trialtracker.persistence")
    private var transactionUpdateTask: Task<Void, Error>?

    private init() {
        migrateLegacyTrialIfNeeded()
    }

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
        if transaction.revocationDate != nil
            || transaction.expirationDate?.isInThePast == true
            || transaction.isUpgraded
        {
            return .cancelledOrExpired
        }
        return transaction.isFreeTrial ? .stillOnTrial : .convertedToPaid
    }

    private func reconcilePersistedTrials(_ trials: [String: StoredTrial]) {
        Task {
            var anyStillActive = false
            for (productID, trial) in trials {
                guard case .verified(let transaction)? = await Transaction.latest(for: productID) else {
                    anyStillActive = true
                    continue
                }
                switch Self.classify(transaction, against: trial) {
                case .convertedToPaid:
                    if self.claimTrial(productID: productID) != nil {
                        self.reportConversion(transaction)
                    }
                case .cancelledOrExpired:
                    self.claimTrial(productID: productID)
                case .stillOnTrial, nil:
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
                    switch Self.classify(transaction, against: trial) {
                    case .convertedToPaid:
                        if self.claimTrial(productID: transaction.productID) != nil {
                            self.reportConversion(transaction)
                        }
                    case .cancelledOrExpired:
                        self.claimTrial(productID: transaction.productID)
                    case .stillOnTrial, nil:
                        break
                    }
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
    private func claimTrial(productID: String) -> StoredTrial? {
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

    private func migrateLegacyTrialIfNeeded() {
        persistenceQueue.sync {
            guard let data = TelemetryDeck.customDefaults?.data(forKey: Self.legacyTrialKey),
                let trial = try? JSONDecoder().decode(StoredTrial.self, from: data)
            else { return }
            var trials = loadTrials()
            if trials[trial.productID] == nil {
                trials[trial.productID] = trial
                saveTrials(trials)
            }
            TelemetryDeck.customDefaults?.removeObject(forKey: Self.legacyTrialKey)
        }
    }

    private func currentTrials() -> [String: StoredTrial] {
        persistenceQueue.sync { loadTrials() }
    }

    private func loadTrials() -> [String: StoredTrial] {
        guard let data = TelemetryDeck.customDefaults?.data(forKey: Self.activeTrialsKey),
            let trials = try? JSONDecoder().decode([String: StoredTrial].self, from: data)
        else { return [:] }
        return trials
    }

    private func saveTrials(_ trials: [String: StoredTrial]) {
        if trials.isEmpty {
            TelemetryDeck.customDefaults?.removeObject(forKey: Self.activeTrialsKey)
        } else if let data = try? JSONEncoder().encode(trials) {
            TelemetryDeck.customDefaults?.set(data, forKey: Self.activeTrialsKey)
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
