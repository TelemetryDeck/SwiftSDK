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
        let productId: String
        let originalTransactionId: UInt64
    }

    static let shared = TrialConversionTracker()

    private static let lastTrialKey = "lastTrial"

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.trialtracker.persistence")
    private var transactionUpdateTask: Task<Void, Error>?

    private var currentTrial: StoredTrial? {
        get {
            if
                let trialData = TelemetryDeck.customDefaults?.data(forKey: Self.lastTrialKey),
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

    private init() {
        // Start observing transactions if there's an active trial
        if currentTrial != nil {
            self.startObservingTransactions()
        }
    }

    /// Call this function only after having validated that the passed transaction is a free trial.
    func freeTrialStarted(transaction: Transaction) {
        let trial = StoredTrial(productId: transaction.productID, originalTransactionId: transaction.originalID)
        self.currentTrial = trial
        self.startObservingTransactions()
    }

    private func clearCurrentTrial() {
        self.currentTrial = nil
        self.stopObservingTransactions()
    }

    private func startObservingTransactions() {
        // Cancel any existing observation
        self.stopObservingTransactions()

        // Start new observation
        self.transactionUpdateTask = Task {
            for await verificationResult in Transaction.updates {
                // Check if transaction is verified
                guard case .verified(let transaction) = verificationResult else { continue }

                // Check if this transaction matches our trial product
                if
                    let currentTrial = self.currentTrial,
                    transaction.productID == currentTrial.productId,
                    transaction.originalID == currentTrial.originalTransactionId
                {

                    // Case 1: Trial converted to paid subscription
                    if !transaction.isUpgraded && !transaction.isFreeTrial {
                        TelemetryDeck.internalSignal(
                            "TelemetryDeck.Purchase.convertedFromTrial",
                            parameters: transaction.purchaseParameters(),
                            floatValue: transaction.priceInUSD()
                        )

                        self.clearCurrentTrial()
                    }

                    // Case 2: Trial was canceled or expired, let's clean up & stop observing
                    else if transaction.revocationDate != nil || transaction.expirationDate?.isInThePast == true {
                        self.clearCurrentTrial()
                    }
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
