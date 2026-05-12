import Foundation
import Testing

@testable import TelemetryDeck

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

    @Test
    func consecutiveFailures_incrementsOnErrorResponse() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(manager.consecutiveFailuresForTesting == 1)

        manager.signalCacheForTesting.push(Self.makeSignal())
        manager.attemptToSendNextBatchOfCachedSignals()
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(manager.consecutiveFailuresForTesting == 2)
    }

    @Test
    func consecutiveFailures_resetsOnSuccess() async throws {
        let manager = Self.makeManager(statusCode: 500)
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.attemptToSendNextBatchOfCachedSignals()
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(manager.consecutiveFailuresForTesting == 1)

        StubURLProtocol.statusCode = 200
        manager.signalCacheForTesting.push(Self.makeSignal())
        manager.attemptToSendNextBatchOfCachedSignals()
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(manager.consecutiveFailuresForTesting == 0)
    }
}
