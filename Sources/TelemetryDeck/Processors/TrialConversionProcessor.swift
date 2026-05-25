#if canImport(StoreKit)
    import Foundation
    import StoreKit

    /// Monitors StoreKit transaction updates to detect when a user converts from a free trial to a paid subscription.
    @available(iOS 15, macCatalyst 15, macOS 12, tvOS 15, watchOS 8, *)
    public actor TrialConversionProcessor: EventProcessor {
        private struct StoredTrial: Codable {
            let productID: String
            let originalTransactionID: UInt64
        }

        private static let lastTrialKey = "lastTrial"

        private var storage: (any ProcessorStorage)?
        private var currentTrial: StoredTrial?
        private var transactionUpdateTask: Task<Void, Error>?
        private var emitter: (any EventSending)?

        /// Creates a trial conversion processor.
        public init() {}

        /// Restores any persisted trial state and starts observing StoreKit transaction updates.
        public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
            self.storage = storage
            self.emitter = emitter
            if let data = await storage.data(forKey: Self.lastTrialKey),
                let trial = try? JSONDecoder().decode(StoredTrial.self, from: data)
            {
                currentTrial = trial
                startObservingTransactions()
            }
        }

        /// Stops observing StoreKit transaction updates.
        public func stop() async {
            stopObservingTransactions()
            emitter = nil
        }

        /// Passes the event through unchanged; trial conversion detection happens via StoreKit observers.
        public func process(
            _ input: EventInput,
            context: EventContext,
            next: @Sendable (EventInput, EventContext) async throws -> Event
        ) async throws -> Event {
            try await next(input, context)
        }

        /// Records the start of a free trial and begins watching for a conversion transaction.
        public func freeTrialStarted(transaction: Transaction) {
            let trial = StoredTrial(productID: transaction.productID, originalTransactionID: transaction.originalID)
            currentTrial = trial
            Task { await persistCurrentTrial() }
            startObservingTransactions()
        }

        private func clearCurrentTrial() async {
            currentTrial = nil
            await storage?.set(nil as Data?, forKey: Self.lastTrialKey)
            stopObservingTransactions()
        }

        private func persistCurrentTrial() async {
            guard let trial = currentTrial,
                let data = try? JSONEncoder().encode(trial)
            else { return }
            await storage?.set(data, forKey: Self.lastTrialKey)
        }

        private func startObservingTransactions() {
            stopObservingTransactions()
            transactionUpdateTask = Task { [weak self] in
                for await verificationResult in Transaction.updates {
                    guard let self else { return }
                    guard case .verified(let transaction) = verificationResult else { continue }

                    let trial = await self.currentTrial
                    guard let trial,
                        transaction.productID == trial.productID,
                        transaction.originalID == trial.originalTransactionID
                    else { continue }

                    if transaction.revocationDate != nil
                        || (transaction.expirationDate.map { $0.timeIntervalSinceNow < 0 } ?? false)
                        || transaction.isUpgraded
                    {
                        await self.clearCurrentTrial()
                    } else if !transaction.isFreeTrial {
                        let params = transaction.purchaseParameters()
                        let usdValue = transaction.priceInUSD()
                        let input = EventInput(
                            DefaultEvents.Purchase.convertedFromTrial.rawValue,
                            parameters: EventParameters(params),
                            floatValue: usdValue,
                            skipsReservedPrefixValidation: true
                        )
                        await self.emitter?.send(input)
                        await self.clearCurrentTrial()
                    }
                }
            }
        }

        private func stopObservingTransactions() {
            transactionUpdateTask?.cancel()
            transactionUpdateTask = nil
        }
    }
#endif
