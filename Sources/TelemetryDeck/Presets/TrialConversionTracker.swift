import StoreKit

/// Responsible for tracking free trial subscriptions and detecting when they convert to paid subscriptions or are canceled.
///
/// This class manages the lifecycle of free trials by:
/// - Storing information about the last active free trial in UserDefaults
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

    private static let lastTrialKey = "lastTrial"

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.trialtracker.persistence")
    private var transactionUpdateTask: Task<Void, Error>?

    private var currentTrial: StoredTrial? {
        get {
            if let trialData = TelemetryDeck.customDefaults?.data(forKey: Self.lastTrialKey),
                let trial = try? JSONDecoder().decode(StoredTrial.self, from: trialData)
            {
                return trial
            }

            return nil
        }

        set {
            self.persistenceQueue.async {
                if let trial = newValue, let encodedData = try? JSONEncoder().encode(trial) {
                    TelemetryDeck.customDefaults?.set(encodedData, forKey: Self.lastTrialKey)
                } else {
                    TelemetryDeck.customDefaults?.removeObject(forKey: Self.lastTrialKey)
                }
            }
        }
    }

    private init() {}

    func start() {
        guard currentTrial != nil else { return }
        reconcilePersistedTrial()
    }

    /// Call this function only after having validated that the passed transaction is a free trial.
    func freeTrialStarted(transaction: Transaction) {
        let trial = StoredTrial(productID: transaction.productID, originalTransactionID: transaction.originalID)
        self.currentTrial = trial
        self.startObservingTransactions()
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

    private func reconcilePersistedTrial() {
        guard let trial = currentTrial else { return }
        Task {
            guard case .verified(let transaction)? = await Transaction.latest(for: trial.productID) else {
                self.startObservingTransactions()
                return
            }
            switch Self.classify(transaction, against: trial) {
            case .convertedToPaid:
                TelemetryDeck.internalSignal(
                    "TelemetryDeck.Purchase.convertedFromTrial",
                    parameters: transaction.purchaseParameters(),
                    floatValue: transaction.priceInUSD()
                )
                self.clearCurrentTrial()
            case .cancelledOrExpired:
                self.clearCurrentTrial()
            case .stillOnTrial, nil:
                self.startObservingTransactions()
            }
        }
    }

    private func clearCurrentTrial() {
        persistenceQueue.sync {
            TelemetryDeck.customDefaults?.removeObject(forKey: Self.lastTrialKey)
        }
        stopObservingTransactions()
    }

    private func startObservingTransactions() {
        self.stopObservingTransactions()

        self.transactionUpdateTask = Task {
            for await verificationResult in Transaction.updates {
                guard case .verified(let transaction) = verificationResult else { continue }

                guard let currentTrial = self.currentTrial else { continue }
                switch Self.classify(transaction, against: currentTrial) {
                case .convertedToPaid:
                    TelemetryDeck.internalSignal(
                        "TelemetryDeck.Purchase.convertedFromTrial",
                        parameters: transaction.purchaseParameters(),
                        floatValue: transaction.priceInUSD()
                    )
                    self.clearCurrentTrial()
                case .cancelledOrExpired:
                    self.clearCurrentTrial()
                case .stillOnTrial, nil:
                    break
                }
            }
        }
    }

    private func stopObservingTransactions() {
        self.transactionUpdateTask?.cancel()
        self.transactionUpdateTask = nil
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
