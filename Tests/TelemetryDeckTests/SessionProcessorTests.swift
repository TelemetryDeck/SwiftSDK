import Foundation
import Testing

@testable import TelemetryDeck

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

@Suite
struct SessionProcessorTests {
    @Test
    func processAddsSessionIDToContext() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()
        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())

        let input = EventInput("test.signal")
        let context = EventContext()

        let mockNext: @Sendable (EventInput, EventContext) async throws -> Event = { _, ctx in
            #expect(ctx.sessionID != nil)
            return Event(
                appID: "test-app",
                type: input.name,
                clientUser: "test-user",
                sessionID: ctx.sessionID?.uuidString,
                receivedAt: Date(),
                payload: [:],
                floatValue: nil,
                isTestMode: false
            )
        }

        let signal = try await processor.process(input, context: context, next: mockNext)

        #expect(signal.sessionID != nil)
    }

    @Test
    func sessionIDChangesAfterStartNewSession() async throws {
        let processor = SessionTrackingProcessor()

        let originalSessionID = await processor.currentSessionID()
        let newSessionID = await processor.startNewSession()

        #expect(originalSessionID != newSessionID)

        let currentSessionID = await processor.currentSessionID()
        #expect(currentSessionID == newSessionID)
    }

    @Test
    func foregroundAfterShortBackgroundKeepsSameSession() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()
        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())

        let sessionBeforeBackground = await processor.currentSessionID()

        #if canImport(AppKit)
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            try? await Task.sleep(nanoseconds: 100_000_000)
            NotificationCenter.default.post(name: NSApplication.willBecomeActiveNotification, object: nil)
        #elseif canImport(UIKit) && !os(watchOS)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            try? await Task.sleep(nanoseconds: 100_000_000)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif

        try? await Task.sleep(nanoseconds: 100_000_000)

        let sessionAfterForeground = await processor.currentSessionID()
        #expect(sessionBeforeBackground == sessionAfterForeground)

        await processor.stop()
    }

    @Test
    func stopCleansUpRegistration() async throws {
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false)
        let storage = InMemoryProcessorStorage()

        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())
        await processor.stop()
    }

    @Test
    func shortBackgroundKeepsSameSession() async throws {
        let clock = MutableClock()
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false, dateProvider: clock.dateProvider)
        let storage = InMemoryProcessorStorage()
        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())

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
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false, dateProvider: clock.dateProvider)
        let storage = InMemoryProcessorStorage()
        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())

        let sessionBefore = await processor.currentSessionID()

        await processor.handleBackground()
        clock.advance(by: 360)
        await processor.handleForeground()

        let sessionAfter = await processor.currentSessionID()
        #expect(sessionBefore != sessionAfter)

        await processor.stop()
    }

    @Test
    func stopPersistsTheLatestSessionDurationAfterRepeatedBackgrounds() async throws {
        let clock = MutableClock()
        let processor = SessionTrackingProcessor(sendSessionStartedEvent: false, dateProvider: clock.dateProvider)
        let storage = WriteOverlapTrackingStorage()
        await processor.start(storage: storage, logger: DefaultLogger(), emitter: MockEventSender())

        for _ in 0..<50 {
            clock.advance(by: 10)
            await processor.handleBackground()
            await processor.handleForeground()
        }
        await processor.stop()

        let data = try #require(await storage.data(forKey: "recentSessions"))
        let sessions = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(sessions.last?["dn"] as? Int == 500)
        #expect(await storage.maxConcurrentDataWrites == 1)
    }
}

private actor WriteOverlapTrackingStorage: ProcessorStorage {
    private let store = InMemoryProcessorStorage()
    private var concurrentDataWrites = 0
    private(set) var maxConcurrentDataWrites = 0

    func data(forKey key: String) async -> Data? { await store.data(forKey: key) }
    func set(_ data: Data?, forKey key: String) async {
        concurrentDataWrites += 1
        maxConcurrentDataWrites = max(maxConcurrentDataWrites, concurrentDataWrites)
        await Task.yield()
        await store.set(data, forKey: key)
        concurrentDataWrites -= 1
    }
    func string(forKey key: String) async -> String? { await store.string(forKey: key) }
    func set(_ value: String?, forKey key: String) async { await store.set(value, forKey: key) }
    func integer(forKey key: String) async -> Int { await store.integer(forKey: key) }
    func set(_ value: Int, forKey key: String) async { await store.set(value, forKey: key) }
    func bool(forKey key: String) async -> Bool { await store.bool(forKey: key) }
    func set(_ value: Bool, forKey key: String) async { await store.set(value, forKey: key) }
    func stringArray(forKey key: String) async -> [String]? { await store.stringArray(forKey: key) }
}
