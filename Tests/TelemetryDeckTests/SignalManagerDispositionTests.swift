import Foundation
import Testing

@testable import TelemetryDeck

// URLSessionConfiguration.protocolClasses is not honored on watchOS, so these tests
// cannot intercept HTTP responses. Run on every other platform.
#if !os(watchOS)

// MARK: - URLProtocol stub

private final class DispositionStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: DispositionStubURLProtocol.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite(.serialized)
struct SignalManagerDispositionTests {

    private static func makeManager(statusCode: Int) -> SignalManager {
        DispositionStubURLProtocol.statusCode = statusCode

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [DispositionStubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)

        let config = TelemetryManagerConfiguration(appID: "test-\(UUID().uuidString)")
        config.urlSession = session
        config.transmitInterval = 10
        config.logHandler = nil

        return SignalManager(configuration: config)
    }

    private static func makeSignal() -> SignalPostBody {
        SignalPostBody(
            receivedAt: Date(),
            appID: "test",
            clientUser: "user",
            sessionID: UUID().uuidString,
            type: "Test.signal",
            floatValue: nil,
            payload: [:],
            isTestMode: "true"
        )
    }

    private func waitForConsecutiveFailures(
        _ manager: SignalManager,
        toEqual expected: Int,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.consecutiveFailuresForTesting != expected, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func waitForSendCompletion(
        _ manager: SignalManager,
        toReach expected: Int,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.sendCompletionsForTesting < expected, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // MARK: Success

    @Test
    func successResponse_clearsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 200)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    // MARK: Drop statuses

    @Test
    func clientError400_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 400)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func clientError401_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 401)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func clientError403_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 403)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func clientError404_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 404)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func clientError413_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 413)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func clientError422_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 422)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func serverError501_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 501)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    @Test
    func serverError505_dropsBatch_andResetsFailures() async throws {
        let manager = Self.makeManager(statusCode: 505)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForSendCompletion(manager, toReach: 1)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }

    // MARK: Retry statuses

    @Test
    func serverError500_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    @Test
    func clientError408_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 408)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    @Test
    func clientError429_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 429)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    @Test
    func serverError502_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 502)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    @Test
    func serverError503_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 503)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    @Test
    func serverError504_requeuesBatch_andIncrementsFailures() async throws {
        let manager = Self.makeManager(statusCode: 504)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }

    // MARK: Drop after retry

    @Test
    func dropAfterRetries_resetsFailureCounter() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.consecutiveFailuresForTesting == 1)

        DispositionStubURLProtocol.statusCode = 403
        manager.signalCacheForTesting.push(Self.makeSignal())
        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 0)

        #expect(manager.signalCacheForTesting.count() == 0)
        #expect(manager.consecutiveFailuresForTesting == 0)
    }
}

#endif // !os(watchOS)
