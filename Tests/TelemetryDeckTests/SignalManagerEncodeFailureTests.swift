import Foundation
import Testing

@testable import TelemetryDeck

// MARK: - URLProtocol stub

private final class EncodeFailureStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestReceived = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        EncodeFailureStubURLProtocol.requestReceived = true
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
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
struct SignalManagerEncodeFailureTests {

    private static func makeManager() -> SignalManager {
        EncodeFailureStubURLProtocol.requestReceived = false

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [EncodeFailureStubURLProtocol.self]
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
    func encodeFailure_requeuesBatchAndRearmsTimer() async throws {
        let manager = Self.makeManager()
        manager.signalCacheForTesting.push(Self.makeSignal())

        manager.shouldFailNextEncodeForTesting = true
        manager.attemptToSendNextBatchOfCachedSignals()
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(EncodeFailureStubURLProtocol.requestReceived == false)
        #expect(manager.signalCacheForTesting.count() == 1)
        #expect(manager.consecutiveFailuresForTesting == 1)
    }
}
