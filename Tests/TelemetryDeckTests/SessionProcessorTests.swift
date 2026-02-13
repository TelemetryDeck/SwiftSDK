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
}
