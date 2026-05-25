import Foundation
import Testing

@testable import TelemetryDeck

// URLSessionConfiguration.protocolClasses is not honored on watchOS, so these tests
// cannot intercept HTTP responses. Run on every other platform.
#if !os(watchOS)

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode: Int = 500

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: StubURLProtocol.statusCode,
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
struct SignalManagerBackoffTests {

    private static func makeManager(statusCode: Int) -> SignalManager {
        StubURLProtocol.statusCode = statusCode

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
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
        timeout: TimeInterval = 15
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.consecutiveFailuresForTesting != expected, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test
    func consecutiveFailures_incrementsOnErrorResponse() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.consecutiveFailuresForTesting == 1)

        manager.signalCacheForTesting.push(Self.makeSignal())
        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 2)

        #expect(manager.consecutiveFailuresForTesting == 2)
    }

    @Test
    func consecutiveFailures_resetsOnSuccess() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 1)

        #expect(manager.consecutiveFailuresForTesting == 1)

        StubURLProtocol.statusCode = 200
        manager.signalCacheForTesting.push(Self.makeSignal())
        manager.attemptToSendNextBatchOfCachedSignals()
        try await waitForConsecutiveFailures(manager, toEqual: 0)

        #expect(manager.consecutiveFailuresForTesting == 0)
    }
}

#endif // !os(watchOS)
