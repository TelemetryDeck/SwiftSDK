import Foundation
import Testing

@testable import TelemetryDeck

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
        #expect(events[0].payload["TelemetryDeck.Referral.ratingValue"] == "8")
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
}
