import Foundation
import Testing

@testable import TelemetryDeck

@Suite
struct InMemoryProcessorStorageTests {
    @Test
    func returnsDefaultsForUnsetKeys() async {
        let storage = InMemoryProcessorStorage()
        await #expect(storage.data(forKey: "x") == nil)
        await #expect(storage.string(forKey: "x") == nil)
        await #expect(storage.integer(forKey: "x") == 0)
        await #expect(storage.bool(forKey: "x") == false)
        await #expect(storage.stringArray(forKey: "x") == nil)
    }

    @Test
    func roundTripsData() async {
        let storage = InMemoryProcessorStorage()
        let value = "hello".data(using: .utf8)!
        await storage.set(value, forKey: "d")
        await #expect(storage.data(forKey: "d") == value)
    }

    @Test
    func roundTripsString() async {
        let storage = InMemoryProcessorStorage()
        await storage.set("world", forKey: "s")
        await #expect(storage.string(forKey: "s") == "world")
    }

    @Test
    func roundTripsInt() async {
        let storage = InMemoryProcessorStorage()
        await storage.set(42, forKey: "i")
        await #expect(storage.integer(forKey: "i") == 42)
    }

    @Test
    func roundTripsBool() async {
        let storage = InMemoryProcessorStorage()
        await storage.set(true, forKey: "b")
        await #expect(storage.bool(forKey: "b") == true)
    }
}

@Suite
struct InMemorySessionProcessorTests {
    private let testConfig = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    @Test
    func processedEventCarriesSessionID() async throws {
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: false)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let event = try await pipeline.process(EventInput("Test.event"), context: EventContext())
        #expect(event.sessionID != nil)

        await processor.stop()
    }

    @Test
    func sessionStartedIsEmittedWhenEnabled() async throws {
        let emitter = CapturingEventSender()
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: true)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)

        let sentNames = await emitter.sentEvents.map(\.name)
        #expect(sentNames.contains(DefaultEvents.Session.started.rawValue))

        await processor.stop()
    }

    @Test
    func sessionStartedIsNotEmittedWhenDisabled() async throws {
        let emitter = CapturingEventSender()
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: false)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)

        let sentNames = await emitter.sentEvents.map(\.name)
        #expect(!sentNames.contains(DefaultEvents.Session.started.rawValue))

        await processor.stop()
    }

    @Test
    func newInstallDetectedIsAbsent() async throws {
        let emitter = CapturingEventSender()
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: true)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: emitter)

        let sentNames = await emitter.sentEvents.map(\.name)
        #expect(!sentNames.contains(DefaultEvents.Acquisition.newInstallDetected.rawValue))

        await processor.stop()
    }

    @Test
    func noRetentionOrAcquisitionParametersOnEvents() async throws {
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: false)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let event = try await pipeline.process(EventInput("Test.event"), context: EventContext())

        let retentionKeys = [
            DefaultParams.Retention.totalSessionsCount.rawValue,
            DefaultParams.Retention.distinctDaysUsed.rawValue,
            DefaultParams.Retention.distinctDaysUsedLastMonth.rawValue,
            DefaultParams.Retention.averageSessionSeconds.rawValue,
            DefaultParams.Retention.previousSessionSeconds.rawValue,
        ]
        for key in retentionKeys {
            #expect(event.payload[key] == nil, "Expected no \(key) in event payload")
        }

        #expect(event.payload[DefaultParams.Acquisition.firstSessionDate.rawValue] == nil)
        #expect(event.payload[DefaultParams.Acquisition.isNewInstall.rawValue] == nil)

        await processor.stop()
    }

    @Test
    func shortBackgroundKeepsSameSession() async throws {
        let clock = MutableClock()
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: false, dateProvider: clock.dateProvider)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())

        let sessionBefore = await processor.currentSessionID()

        await processor.handleBackground()
        clock.advance(by: 60)
        await processor.handleForeground()

        let sessionAfter = await processor.currentSessionID()
        #expect(sessionBefore == sessionAfter)

        await processor.stop()
    }

    @Test
    func longBackgroundRotatesSession() async throws {
        let clock = MutableClock()
        let processor = InMemorySessionProcessor(sendSessionStartedEvent: false, dateProvider: clock.dateProvider)
        await processor.start(storage: InMemoryProcessorStorage(), logger: NoOpLogger(), emitter: MockEventSender())

        let sessionBefore = await processor.currentSessionID()

        await processor.handleBackground()
        clock.advance(by: 360)
        await processor.handleForeground()

        let sessionAfter = await processor.currentSessionID()
        #expect(sessionBefore != sessionAfter)

        await processor.stop()
    }
}

@Suite
struct InMemoryModeNoDiskWriteTests {
    @Test
    func engineWithInMemoryStorageDoesNotWriteToUserDefaults() async throws {
        let appID = "td-in-memory-no-disk-test"
        let appIdHash = CryptoHashing.sha256(string: appID, salt: "")
        let suiteName = "com.telemetrydeck.\(appIdHash.suffix(12))"

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

        let config = TelemetryDeck.Config(appID: appID, namespace: "test")
        let engine = await TelemetryEngine.create(
            configuration: config,
            processors: [InMemorySessionProcessor()],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            storage: InMemoryProcessorStorage()
        )
        await engine.send(EventInput("Test.inMemory"))
        await engine.shutdown()

        let defaults = UserDefaults(suiteName: suiteName)
        let sdkKeys = ["recentSessions", "deletedSessionsCount", "firstSessionDate", "distinctDaysUsed", "installID", "durationTrackerState"]
        for key in sdkKeys {
            #expect(defaults?.object(forKey: key) == nil, "Expected no \(key) in UserDefaults suite after in-memory operation")
        }

        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}
