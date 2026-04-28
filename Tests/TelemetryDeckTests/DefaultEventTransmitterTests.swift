import Foundation
import Testing

@testable import TelemetryDeck

private func createTestEvent(type: String = "test.event") -> Event {
    Event(
        appID: "test-app-id",
        type: type,
        clientUser: "test-user",
        sessionID: "test-session",
        receivedAt: Date(),
        payload: ["key": "value"],
        floatValue: nil,
        isTestMode: false
    )
}

@Suite("DefaultEventTransmitter Tests")
struct DefaultEventTransmitterTests {
    @Test
    func serviceURLConstructedCorrectly() async {
        let baseURL = URL(string: "https://api.example.com")!
        let namespace = "test-namespace"
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: namespace,
            apiBaseURL: baseURL
        )
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 200, url: baseURL)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = stub.lastRequest
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            let expectedPath = "/v2/namespace/\(namespace)"
            #expect(url.path == expectedPath)
            #expect(url.scheme == baseURL.scheme)
            #expect(url.host == baseURL.host)
        }
    }

    @Test
    func serviceURLPreservesBaseURLPathComponents() async {
        let baseURL = URL(string: "https://example.com/array/sensors")!
        let namespace = "test-namespace"
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: namespace,
            apiBaseURL: baseURL
        )
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 200, url: baseURL)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = stub.lastRequest
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            #expect(url.path == "/array/sensors/v2/namespace/\(namespace)")
            #expect(url.scheme == "https")
            #expect(url.host == "example.com")
        }
    }

    @Test
    func serviceURLPreservesBaseURLPathComponentsWithTrailingSlash() async {
        let baseURL = URL(string: "https://example.com/array/sensors/")!
        let namespace = "test-namespace"
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: namespace,
            apiBaseURL: baseURL
        )
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 200, url: baseURL)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = stub.lastRequest
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            #expect(url.path == "/array/sensors/v2/namespace/\(namespace)")
            #expect(url.scheme == "https")
            #expect(url.host == "example.com")
        }
    }

    @Test
    func transmitReturnsEmptyOnSuccess() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [
            createTestEvent(type: "event.one"),
            createTestEvent(type: "event.two"),
            createTestEvent(type: "event.three"),
        ]

        let failed = await transmitter.transmit(events)

        #expect(stub.lastRequest != nil)
        #expect(failed.isEmpty)
    }

    @Test
    func transmitReturnsEmptyOn201Created() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 201, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let failed = await transmitter.transmit([createTestEvent()])

        #expect(stub.lastRequest != nil)
        #expect(failed.isEmpty)
    }

    @Test
    func transmitReturnsOriginalEventsOnFailure() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 500, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [
            createTestEvent(type: "event.one"),
            createTestEvent(type: "event.two"),
        ]

        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)
        #expect(failed[0].type == "event.one")
        #expect(failed[1].type == "event.two")
    }

    @Test
    func transmitReturnsOriginalEventsOn400BadRequest() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 400, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)
    }

    @Test
    func transmitReturnsOriginalEventsOnNetworkError() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(
            error: NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorNotConnectedToInternet,
                userInfo: nil
            )
        )

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)
    }

    @Test
    func transmitSetsCorrectHTTPHeaders() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = stub.lastRequest
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(capturedRequest?.httpBody != nil)
    }

    @Test
    func flushCallsTransmitForCachedEvents() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitCallCount = Locked<Int>(0)
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!) {
            transmitCallCount.withLock { $0 += 1 }
        }

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        await cache.add(createTestEvent(type: "event.one"))
        await cache.add(createTestEvent(type: "event.two"))
        await cache.add(createTestEvent(type: "event.three"))

        let countBefore = await cache.count()
        #expect(countBefore == 3)

        await transmitter.flush()

        let countAfter = await cache.count()
        #expect(countAfter == 0)

        let callCount = transmitCallCount.withLock { $0 }
        #expect(callCount == 1)
    }

    @Test
    func flushReAddsFailedEventsToCache() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 503, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        await cache.add(createTestEvent(type: "event.one"))
        await cache.add(createTestEvent(type: "event.two"))

        let countBefore = await cache.count()
        #expect(countBefore == 2)

        await transmitter.flush()

        let countAfter = await cache.count()
        #expect(countAfter == 2)
    }

    @Test
    func flushWithEmptyCacheDoesNothing() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let transmitCallCount = Locked<Int>(0)
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!) {
            transmitCallCount.withLock { $0 += 1 }
        }

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        await transmitter.flush()

        let callCount = transmitCallCount.withLock { $0 }
        #expect(callCount == 0)
    }
}

private final class StubHTTPClient: HTTPDataLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastRequest: URLRequest?

    private let result: Result<(Data, URLResponse), Error>
    private let onRequest: (() -> Void)?

    init(statusCode: Int, url: URL, onRequest: (() -> Void)? = nil) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        self.result = .success((Data(), response))
        self.onRequest = onRequest
    }

    init(error: Error, onRequest: (() -> Void)? = nil) {
        self.result = .failure(error)
        self.onRequest = onRequest
    }

    var lastRequest: URLRequest? {
        lock.withLock { _lastRequest }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { _lastRequest = request }
        onRequest?()
        return try result.get()
    }
}

private final class Locked<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.withLock { body(&value) }
    }
}
