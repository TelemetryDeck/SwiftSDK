import Foundation
import Testing

@testable import TelemetryDeck

struct RetentionProcessorTests {
    let testConfig = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    @Test
    func firstSessionRecordSetsFirstSessionDate() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Acquisition.firstSessionDate"] != nil)

        guard case .string(let dateString) = signal.payload["TelemetryDeck.Acquisition.firstSessionDate"] else {
            Issue.record("firstSessionDate is not a string PayloadValue")
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let date = formatter.date(from: dateString)
        #expect(date != nil)

        await processor.stop()
    }

    @Test
    func totalSessionsCountIncrementsOnStartNewSession() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())
        await processor.startNewSession()

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Retention.totalSessionsCount"] == 2)

        await processor.stop()
    }

    @Test
    func distinctDaysUsedTracksUniqueDays() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Retention.distinctDaysUsed"] == 1)

        await processor.stop()
    }

    @Test
    func averageSessionSecondsCalculatedFromCompletedSessions() async throws {
        let storage = InMemoryProcessorStorage()

        let session1 = """
            [{"st":\(Date().addingTimeInterval(-200).timeIntervalSince1970),"dn":100}]
            """.data(using: .utf8)!
        await storage.set(session1, forKey: "recentSessions")

        let processor = SessionTrackingProcessor()
        let logger = NoOpLogger()
        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Retention.averageSessionSeconds"] != nil)
        #expect(signal.payload["TelemetryDeck.Retention.averageSessionSeconds"] == 100)

        if case .int(let avg) = signal.payload["TelemetryDeck.Retention.averageSessionSeconds"] {
            #expect(avg == 100)
        } else {
            Issue.record("averageSessionSeconds not found or not parseable")
        }

        await processor.stop()
    }

    @Test
    func averageSessionSecondsIsNegativeOneWhenNoCompletedSessions() async throws {
        let processor = SessionTrackingProcessor()
        let storage = InMemoryProcessorStorage()
        let logger = NoOpLogger()

        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Retention.averageSessionSeconds"] == -1)

        await processor.stop()
    }

    @Test
    func previousSessionSecondsReportedAfterTwoSessions() async throws {
        let storage = InMemoryProcessorStorage()

        let sessions = """
            [{"st":\(Date().addingTimeInterval(-300).timeIntervalSince1970),"dn":120}]
            """.data(using: .utf8)!
        await storage.set(sessions, forKey: "recentSessions")

        let processor = SessionTrackingProcessor()
        let logger = NoOpLogger()
        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Retention.previousSessionSeconds"] != nil)
        #expect(signal.payload["TelemetryDeck.Retention.previousSessionSeconds"] == 120)

        if case .int(let prev) = signal.payload["TelemetryDeck.Retention.previousSessionSeconds"] {
            #expect(prev == 120)
        } else {
            Issue.record("previousSessionSeconds not found or not parseable")
        }

        await processor.stop()
    }

    @Test
    func cleanOldSessionsRemovesEntriesOlderThan90Days() async throws {
        let storage = InMemoryProcessorStorage()

        let oldDate = Date().addingTimeInterval(-91 * 24 * 3600)
        let recentDate = Date().addingTimeInterval(-10 * 24 * 3600)

        let sessions = """
            [{"st":\(oldDate.timeIntervalSince1970),"dn":100},{"st":\(recentDate.timeIntervalSince1970),"dn":200}]
            """.data(using: .utf8)!
        await storage.set(sessions, forKey: "recentSessions")
        await storage.set(5, forKey: "deletedSessionsCount")

        let processor = SessionTrackingProcessor()
        let logger = NoOpLogger()
        await processor.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        // Pre-loaded: 1 old (deleted, count → 6) + 1 recent + 1 from start() = 2 recent + 6 deleted = 8
        let totalSessionsStr = signal.payload["TelemetryDeck.Retention.totalSessionsCount"]
        #expect(totalSessionsStr == 8)

        await processor.stop()

        try await Task.sleep(nanoseconds: 200_000_000)

        let processor2 = SessionTrackingProcessor()
        await processor2.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline2 = ProcessorPipeline(
            processors: [processor2],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input2 = EventInput("Test.signal2")
        let context2 = EventContext()
        let signal2 = try await pipeline2.process(input2, context: context2)

        // Previous 2 recent sessions + new session from start() = 3 recent + 6 deleted = 9
        #expect(signal2.payload["TelemetryDeck.Retention.totalSessionsCount"] == 9)

        await processor2.stop()
    }

    @Test
    func persistenceRoundtrip() async throws {
        let storage = InMemoryProcessorStorage()

        let processor1 = SessionTrackingProcessor()
        let logger = NoOpLogger()
        await processor1.start(storage: storage, logger: logger, emitter: MockEventSender())

        await processor1.startNewSession()

        let pipeline1 = ProcessorPipeline(
            processors: [processor1],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input1 = EventInput("Test.signal")
        let context1 = EventContext()
        let signal1 = try await pipeline1.process(input1, context: context1)

        #expect(signal1.payload["TelemetryDeck.Retention.totalSessionsCount"] == 2)
        #expect(signal1.payload["TelemetryDeck.Acquisition.firstSessionDate"] != nil)

        let firstSessionDate = signal1.payload["TelemetryDeck.Acquisition.firstSessionDate"]

        await processor1.stop()

        try await Task.sleep(nanoseconds: 200_000_000)

        let processor2 = SessionTrackingProcessor()
        await processor2.start(storage: storage, logger: logger, emitter: MockEventSender())

        let pipeline2 = ProcessorPipeline(
            processors: [processor2],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input2 = EventInput("Test.signal2")
        let context2 = EventContext()
        let signal2 = try await pipeline2.process(input2, context: context2)

        // processor1 persisted 2 sessions; processor2.start() records 1 more → total = 3
        #expect(signal2.payload["TelemetryDeck.Retention.totalSessionsCount"] == 3)
        #expect(signal2.payload["TelemetryDeck.Acquisition.firstSessionDate"] == firstSessionDate)

        await processor2.stop()
    }
}
