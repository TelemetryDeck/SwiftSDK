import Foundation
import Testing

@testable import TelemetryDeck

private actor InitializationProbeProcessor: EventProcessor {
    nonisolated let starts: AsyncStream<Void>
    private let startsContinuation: AsyncStream<Void>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var isStartReleased: Bool
    private var heldStarts: [CheckedContinuation<Void, Never>] = []

    init(holdsStart: Bool) {
        isStartReleased = !holdsStart
        (starts, startsContinuation) = AsyncStream.makeStream()
    }

    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        try await next(input, context)
    }

    func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        startCount += 1
        startsContinuation.yield()
        guard !isStartReleased else { return }
        await withCheckedContinuation { heldStarts.append($0) }
    }

    func stop() async {
        stopCount += 1
    }

    func releaseStart() {
        isStartReleased = true
        let held = heldStarts
        heldStarts = []
        for continuation in held {
            continuation.resume()
        }
    }
}

@Suite(.serialized)
struct PresetIntegrationTests {

    // MARK: - Navigation

    @Test
    func navigationPathChangedUsesEmptySourceOnFirstCall() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "navigation-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.navigationPathChanged(to: "profile")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Navigation.pathChanged")
        #expect(events[0].payload["TelemetryDeck.Navigation.sourcePath"] == "")
        #expect(events[0].payload["TelemetryDeck.Navigation.destinationPath"] == "profile")
        #expect(events[0].payload["TelemetryDeck.Navigation.identifier"] == " -> profile")

        await TelemetryDeck.terminate()
    }

    @Test
    func navigationPathChangedWithSourceAndDestination() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "navigation-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.navigationPathChanged(from: "home", to: "settings")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Navigation.pathChanged")
        #expect(events[0].payload["TelemetryDeck.Navigation.sourcePath"] == "home")
        #expect(events[0].payload["TelemetryDeck.Navigation.destinationPath"] == "settings")
        #expect(events[0].payload["TelemetryDeck.Navigation.identifier"] == "home -> settings")
        #expect(events[0].payload["TelemetryDeck.Navigation.schemaVersion"] == "1")

        await TelemetryDeck.terminate()
    }

    @Test
    func navigationPathChangedChainsPreviousDestination() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "navigation-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.navigationPathChanged(to: "first")

        let firstSignals = await cache.pop()
        #expect(firstSignals.count == 1)
        #expect(firstSignals[0].payload["TelemetryDeck.Navigation.destinationPath"] == "first")

        await TelemetryDeck.navigationPathChanged(to: "second")

        let secondSignals = await cache.pop()
        #expect(secondSignals.count == 1)
        #expect(secondSignals[0].payload["TelemetryDeck.Navigation.sourcePath"] == "first")
        #expect(secondSignals[0].payload["TelemetryDeck.Navigation.destinationPath"] == "second")
        #expect(secondSignals[0].payload["TelemetryDeck.Navigation.identifier"] == "first -> second")

        await TelemetryDeck.terminate()
    }

    @Test
    func navigationSignalNameIsCorrect() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "navigation-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.navigationPathChanged(to: "anyPath")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Navigation.pathChanged")

        await TelemetryDeck.terminate()
    }

    // MARK: - Pirate Metrics

    @Test
    func acquiredUserSendsCorrectSignalNameAndChannel() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "pirate-metrics-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.acquiredUser(channel: "organic-search")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Acquisition.userAcquired")
        #expect(events[0].payload["TelemetryDeck.Acquisition.channel"] == "organic-search")

        await TelemetryDeck.terminate()
    }

    @Test
    func leadStartedIncludesLeadID() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "pirate-metrics-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.leadStarted(leadID: "lead-12345")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Acquisition.leadStarted")
        #expect(events[0].payload["TelemetryDeck.Acquisition.leadID"] == "lead-12345")

        await TelemetryDeck.terminate()
    }

    @Test
    func coreFeatureUsedIncludesFeatureName() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "pirate-metrics-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.coreFeatureUsed(featureName: "photo-editor")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Activation.coreFeatureUsed")
        #expect(events[0].payload["TelemetryDeck.Activation.featureName"] == "photo-editor")

        await TelemetryDeck.terminate()
    }

    @Test
    func userRatingSubmittedRejectsOutOfRangeRating() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "pirate-metrics-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.userRatingSubmitted(rating: 11)

        let count = await cache.count()
        #expect(count == 0)

        await TelemetryDeck.terminate()
    }

    @Test
    func userRatingSubmittedAcceptsValidRating() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "pirate-metrics-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.userRatingSubmitted(rating: 8, comment: "Great app!")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Referral.userRatingSubmitted")
        #expect(events[0].payload["TelemetryDeck.Referral.ratingValue"] == 8)
        #expect(events[0].payload["TelemetryDeck.Referral.ratingComment"] == "Great app!")
        #expect(events[0].floatValue == nil)

        await TelemetryDeck.terminate()
    }

    // MARK: - Error Reporting

    @Test
    func errorOccurredSendsSignalWithIDAndCategory() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "error-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.errorOccurred(id: "error-001", category: .userInput)

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Error.occurred")
        #expect(events[0].payload["TelemetryDeck.Error.id"] == "error-001")
        #expect(events[0].payload["TelemetryDeck.Error.category"] == "user-input")

        await TelemetryDeck.terminate()
    }

    @Test
    func errorOccurredWithIdentifiableErrorUsesErrorID() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "error-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        struct TestError: LocalizedError, IdentifiableError {
            let id = "identifiable-error-123"
            var errorDescription: String? { "Test error description" }
        }

        await TelemetryDeck.errorOccurred(identifiableError: TestError(), category: .thrownException)

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Error.occurred")
        #expect(events[0].payload["TelemetryDeck.Error.id"] == "identifiable-error-123")
        #expect(events[0].payload["TelemetryDeck.Error.category"] == "thrown-exception")
        #expect(events[0].payload["TelemetryDeck.Error.message"] == "Test error description")

        await TelemetryDeck.terminate()
    }

    @Test
    func errorOccurredWithMessageIncludesMessage() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "error-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.errorOccurred(id: "error-with-message", category: .appState, message: "Custom error message")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Error.occurred")
        #expect(events[0].payload["TelemetryDeck.Error.id"] == "error-with-message")
        #expect(events[0].payload["TelemetryDeck.Error.category"] == "app-state")
        #expect(events[0].payload["TelemetryDeck.Error.message"] == "Custom error message")

        await TelemetryDeck.terminate()
    }

    @Test
    func errorOccurredWithoutCategoryOmitsIt() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "error-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.errorOccurred(id: "error-no-category")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Error.occurred")
        #expect(events[0].payload["TelemetryDeck.Error.id"] == "error-no-category")
        #expect(events[0].payload["TelemetryDeck.Error.category"] == nil)

        await TelemetryDeck.terminate()
    }

    @Test
    func doubleInitializationIsIgnored() async throws {
        await TelemetryDeck.terminate()

        let firstCache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "double-init-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: firstCache,
            transmitter: SpyEventTransmitter()
        )

        let secondCache = InMemoryEventCache()
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: secondCache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.event("Test.doubleInit")

        let firstCount = await firstCache.count()
        let secondCount = await secondCache.count()
        #expect(firstCount == 1)
        #expect(secondCount == 0)

        await TelemetryDeck.terminate()
    }

    // MARK: - Initialization

    @Test
    func emptyAppIDPreventsInitialization() async {
        await #expect(throws: TelemetryDeckError.self) {
            try await TelemetryDeck.initialize(
                configuration: TelemetryDeck.Config(appID: "", namespace: "test")
            )
        }
        await TelemetryDeck.terminate()
    }

    @Test
    func emptyNamespacePreventsInitialization() async {
        await #expect(throws: TelemetryDeckError.self) {
            try await TelemetryDeck.initialize(
                configuration: TelemetryDeck.Config(appID: "test", namespace: "")
            )
        }
        await TelemetryDeck.terminate()
    }

    @Test
    func eventsAreDroppedAfterFailedInitialization() async {
        await TelemetryDeck.terminate()

        try? await TelemetryDeck.initialize(
            configuration: TelemetryDeck.Config(appID: "", namespace: "test")
        )

        await TelemetryDeck.event("Should.not.send")

        let client = await TelemetryDeck.client()
        #expect(client == nil)

        await TelemetryDeck.terminate()
    }

    // MARK: - Pre-Initialization Buffering

    @Test
    func eventsBeforeInitAreDeliveredAfterInit() async throws {
        await TelemetryDeck.terminate()

        await TelemetryDeck.event("Buffer.first", parameters: ["key": "value1"])
        await TelemetryDeck.event("Buffer.second", parameters: ["key": "value2"])

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "test-buffering", namespace: "test")

        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter(),
            logger: NoOpLogger()
        )

        let events = await cache.pop()
        #expect(events.count == 2)
        #expect(events.contains { $0.type == "Buffer.first" })
        #expect(events.contains { $0.type == "Buffer.second" })
        #expect(events.first { $0.type == "Buffer.first" }?.payload["key"] == "value1")
        #expect(events.first { $0.type == "Buffer.second" }?.payload["key"] == "value2")

        await TelemetryDeck.terminate()
    }

    @Test
    func bufferedTimestampsReflectCreationTime() async throws {
        await TelemetryDeck.terminate()

        let before = Date()
        await TelemetryDeck.event("Timestamp.test")
        try await Task.sleep(nanoseconds: 100_000_000)

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "test-timestamps", namespace: "test")

        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter(),
            logger: NoOpLogger()
        )

        let events = await cache.pop()
        #expect(events.count == 1)

        let eventTime = events[0].receivedAt
        #expect(eventTime >= before)
        #expect(eventTime < Date())

        await TelemetryDeck.terminate()
    }

    @Test
    func terminateClearsBuffer() async throws {
        await TelemetryDeck.terminate()

        await TelemetryDeck.event("Discarded.event")
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "test-clear-buffer", namespace: "test")

        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter(),
            logger: NoOpLogger()
        )

        let count = await cache.count()
        #expect(count == 0)

        await TelemetryDeck.terminate()
    }

    @Test
    func concurrentSignalsDuringInitAllArrive() async throws {
        await TelemetryDeck.terminate()

        let eventCount = 20

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<eventCount {
                group.addTask {
                    await TelemetryDeck.event("Concurrent.event.\(i)")
                }
            }
        }

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "test-concurrent", namespace: "test")

        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter(),
            logger: NoOpLogger()
        )

        let count = await cache.count()
        #expect(count == eventCount)

        await TelemetryDeck.terminate()
    }

    // MARK: - Purchases

    @Test
    func purchaseCompletedEmitsCorrectEventAndPayload() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "purchase-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.purchaseCompleted(
            productID: "com.example.monthly",
            type: .subscription,
            price: Decimal(9.99),
            currencyCode: "USD",
            countryCode: "US"
        )

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Purchase.completed")
        #expect(events[0].payload["TelemetryDeck.Purchase.productID"] == "com.example.monthly")
        #expect(events[0].payload["TelemetryDeck.Purchase.type"] == "subscription")
        #expect(events[0].payload["TelemetryDeck.Purchase.currencyCode"] == "USD")
        #expect(events[0].payload["TelemetryDeck.Purchase.countryCode"] == "US")
        #expect(events[0].floatValue != nil)
        #expect(abs((events[0].floatValue ?? 0) - 9.99) < 0.001)

        await TelemetryDeck.terminate()
    }

    @Test
    func purchaseCompletedMergesCallerParameters() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "purchase-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.purchaseCompleted(
            productID: "com.example.pro",
            type: .oneTimePurchase,
            price: Decimal(4.99),
            currencyCode: "USD",
            parameters: ["custom.key": "custom.value"]
        )

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].payload["custom.key"] == "custom.value")
        #expect(events[0].payload["TelemetryDeck.Purchase.type"] == "one-time-purchase")

        await TelemetryDeck.terminate()
    }

    @Test
    func convertedFromTrialEmitsCorrectEventWithFloatValue() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "purchase-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.convertedFromTrial(
            productID: "com.example.annual",
            type: .subscription,
            price: Decimal(49.99),
            currencyCode: "EUR"
        )

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Purchase.convertedFromTrial")
        #expect(events[0].payload["TelemetryDeck.Purchase.productID"] == "com.example.annual")
        #expect(events[0].payload["TelemetryDeck.Purchase.currencyCode"] == "EUR")
        #expect(events[0].floatValue != nil)

        await TelemetryDeck.terminate()
    }

    @Test
    func freeTrialStartedEmitsCorrectEventWithNoFloatValue() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let config = TelemetryDeck.Config(appID: "purchase-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [],
            cache: cache,
            transmitter: SpyEventTransmitter()
        )

        await TelemetryDeck.freeTrialStarted(
            productID: "com.example.monthly",
            type: .subscription,
            currencyCode: "USD",
            countryCode: "US"
        )

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].type == "TelemetryDeck.Purchase.freeTrialStarted")
        #expect(events[0].payload["TelemetryDeck.Purchase.productID"] == "com.example.monthly")
        #expect(events[0].payload["TelemetryDeck.Purchase.currencyCode"] == "USD")
        #expect(events[0].floatValue == nil)

        await TelemetryDeck.terminate()
    }

    // MARK: - Duration

    @Test
    func stopAndSendDurationEventLogsNoReservedPrefixError() async throws {
        await TelemetryDeck.terminate()

        let cache = InMemoryEventCache()
        let logger = SpyLogger()
        let config = TelemetryDeck.Config(appID: "duration-test", namespace: "test")
        try await TelemetryDeck.initialize(
            configuration: config,
            processors: [ValidationProcessor()],
            cache: cache,
            transmitter: SpyEventTransmitter(),
            logger: logger
        )

        await TelemetryDeck.startDurationEvent("Test.duration")
        await TelemetryDeck.stopAndSendDurationEvent("Test.duration")

        let events = await cache.pop()
        #expect(events.count == 1)
        #expect(events[0].payload["TelemetryDeck.Signal.durationInSeconds"] != nil)
        #expect(logger.errorMessages().isEmpty)

        await TelemetryDeck.terminate()
    }

    // MARK: - Initialization

    private static func initialize(with processor: InitializationProbeProcessor, logger: SpyLogger) async throws {
        try await TelemetryDeck.initialize(
            configuration: TelemetryDeck.Config(appID: "initialize-test", namespace: "test"),
            processors: [processor],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            logger: logger,
            storage: InMemoryProcessorStorage()
        )
    }

    private static func waitUntilAClientChangeIsWaiting() async throws {
        var attempts = 0
        while await TelemetryDeck.clientChangeWaiterCount() == 0, attempts < 100 {
            attempts += 1
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test
    func overlappingInitializeCallsStartASingleEngine() async throws {
        await TelemetryDeck.terminate()

        let processor = InitializationProbeProcessor(holdsStart: true)
        let logger = SpyLogger()
        var starts = processor.starts.makeAsyncIterator()
        let first = Task { try await Self.initialize(with: processor, logger: logger) }
        await starts.next()
        let duplicate = Task {
            try await Self.initialize(with: processor, logger: logger)
            return await TelemetryDeck.client() != nil
        }
        try await Self.waitUntilAClientChangeIsWaiting()
        await processor.releaseStart()
        try await first.value
        let isReadyAfterDuplicate = try await duplicate.value

        #expect(await processor.startCount == 1)
        #expect(isReadyAfterDuplicate)
        #expect(logger.hasErrorContaining("called more than once"))

        await TelemetryDeck.terminate()
    }

    @Test
    func duplicateInitializeCallerCanStartHeartbeatsRightAway() async throws {
        await TelemetryDeck.terminate()

        let processor = InitializationProbeProcessor(holdsStart: true)
        let logger = SpyLogger()
        var starts = processor.starts.makeAsyncIterator()
        let first = Task { try await Self.initialize(with: processor, logger: logger) }
        await starts.next()
        let duplicate = Task {
            try await Self.initialize(with: processor, logger: logger)
            await TelemetryDeck.startHeartbeatEvents(.minute)
            return await TelemetryDeck.client()?.heartbeatTracker.isRunning ?? false
        }
        try await Self.waitUntilAClientChangeIsWaiting()
        await processor.releaseStart()
        try await first.value
        let areHeartbeatsRunning = try await duplicate.value

        #expect(areHeartbeatsRunning)
        #expect(!logger.hasErrorContaining("not initialized"))

        await TelemetryDeck.terminate()
    }

    @Test
    func terminateDuringInitializeLeavesNoEngineRunning() async throws {
        await TelemetryDeck.terminate()

        let processor = InitializationProbeProcessor(holdsStart: true)
        var starts = processor.starts.makeAsyncIterator()
        let initialization = Task { try await Self.initialize(with: processor, logger: SpyLogger()) }
        await starts.next()
        let termination = Task { await TelemetryDeck.terminate() }
        try await Self.waitUntilAClientChangeIsWaiting()
        await processor.releaseStart()
        try await initialization.value
        await termination.value

        #expect(await TelemetryDeck.client() == nil)
        #expect(await processor.stopCount == 1)

        let laterProcessor = InitializationProbeProcessor(holdsStart: false)
        try await Self.initialize(with: laterProcessor, logger: SpyLogger())

        #expect(await TelemetryDeck.client() != nil)
        #expect(await laterProcessor.startCount == 1)

        await TelemetryDeck.terminate()
    }

    @Test
    func terminateFromCancelledTaskLetsTheRequestInFlightComplete() async throws {
        await TelemetryDeck.terminate()

        let configuration = TelemetryDeck.Config(appID: "terminate-test", namespace: "test")
        let cache = InMemoryEventCache()
        let client = ScriptedHTTPClient()
        let transmitter = DefaultEventTransmitter(
            configuration: configuration,
            cache: cache,
            logger: NoOpLogger(),
            httpClient: client
        )
        await cache.add(makeEvent(type: "Before.terminate"))
        try await TelemetryDeck.initialize(
            configuration: configuration,
            processors: [],
            cache: cache,
            transmitter: transmitter,
            logger: NoOpLogger(),
            storage: InMemoryProcessorStorage()
        )
        await client.waitForRequests(1)

        let termination = Task { await TelemetryDeck.terminate() }
        termination.cancel()
        client.respond(statusCode: 200)
        await termination.value

        #expect(client.cancelledRequestCount == 0)
        #expect(try client.sentEventTypes() == [["Before.terminate"]])
        #expect(await cache.count() == 0)
        #expect(await TelemetryDeck.client() == nil)
    }
}
