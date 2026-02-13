import Foundation
import Testing

@testable import TelemetryDeck

private final class MockURLProtocol: URLProtocol {
    private static let handlerLock = NSLock()
    private nonisolated(unsafe) static var responseHandler: ((URLRequest) -> (HTTPURLResponse?, Error?))?

    static func setResponseHandler(_ handler: @escaping (URLRequest) -> (HTTPURLResponse?, Error?)) {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        responseHandler = handler
    }

    static func reset() {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        responseHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.handlerLock.lock()
        let handler = Self.responseHandler
        Self.handlerLock.unlock()

        guard let handler = handler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockError", code: -1))
            return
        }

        let (response, error) = handler(request)

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private func createMockURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

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

@Suite("DefaultEventTransmitter Tests", .serialized)
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

        let requestCapture = Locked<URLRequest?>(nil)
        MockURLProtocol.setResponseHandler { request in
            requestCapture.withLock { $0 = request }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let testTransmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let event = createTestEvent()
        _ = await testTransmitter.transmit([event])

        let capturedRequest = requestCapture.withLock { $0 }
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            let expectedPath = "/v2/namespace/\(namespace)"
            #expect(url.path == expectedPath)
            #expect(url.scheme == baseURL.scheme)
            #expect(url.host == baseURL.host)
        }

        MockURLProtocol.reset()
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

        let requestCapture = Locked<URLRequest?>(nil)
        MockURLProtocol.setResponseHandler { request in
            requestCapture.withLock { $0 = request }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = requestCapture.withLock { $0 }
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            #expect(url.path == "/array/sensors/v2/namespace/\(namespace)")
            #expect(url.scheme == "https")
            #expect(url.host == "example.com")
        }

        MockURLProtocol.reset()
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

        let requestCapture = Locked<URLRequest?>(nil)
        MockURLProtocol.setResponseHandler { request in
            requestCapture.withLock { $0 = request }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        _ = await transmitter.transmit([createTestEvent()])

        let capturedRequest = requestCapture.withLock { $0 }
        #expect(capturedRequest != nil)

        if let url = capturedRequest?.url {
            #expect(url.path == "/array/sensors/v2/namespace/\(namespace)")
            #expect(url.scheme == "https")
            #expect(url.host == "example.com")
        }

        MockURLProtocol.reset()
    }

    @Test
    func transmitReturnsEmptyOnSuccess() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [
            createTestEvent(type: "event.one"),
            createTestEvent(type: "event.two"),
            createTestEvent(type: "event.three"),
        ]

        let failed = await transmitter.transmit(events)

        #expect(failed.isEmpty)

        MockURLProtocol.reset()
    }

    @Test
    func transmitReturnsEmptyOn201Created() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.isEmpty)

        MockURLProtocol.reset()
    }

    @Test
    func transmitReturnsOriginalEventsOnFailure() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [
            createTestEvent(type: "event.one"),
            createTestEvent(type: "event.two"),
        ]

        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)
        #expect(failed[0].type == "event.one")
        #expect(failed[1].type == "event.two")

        MockURLProtocol.reset()
    }

    @Test
    func transmitReturnsOriginalEventsOn400BadRequest() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)

        MockURLProtocol.reset()
    }

    @Test
    func transmitReturnsOriginalEventsOnNetworkError() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let error = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorNotConnectedToInternet,
                userInfo: nil
            )
            return (nil, error)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count)

        MockURLProtocol.reset()
    }

    @Test
    func transmitSetsCorrectHTTPHeaders() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        let requestCapture = Locked<URLRequest?>(nil)
        MockURLProtocol.setResponseHandler { request in
            requestCapture.withLock { $0 = request }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        let events = [createTestEvent()]
        _ = await transmitter.transmit(events)

        let capturedRequest = requestCapture.withLock { $0 }
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(capturedRequest?.httpBodyStream != nil)

        MockURLProtocol.reset()
    }

    @Test
    func flushCallsTransmitForCachedEvents() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        let transmitCallCount = Locked<Int>(0)
        MockURLProtocol.setResponseHandler { request in
            transmitCallCount.withLock { $0 += 1 }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
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

        MockURLProtocol.reset()
    }

    @Test
    func flushReAddsFailedEventsToCache() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        MockURLProtocol.setResponseHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        await cache.add(createTestEvent(type: "event.one"))
        await cache.add(createTestEvent(type: "event.two"))

        let countBefore = await cache.count()
        #expect(countBefore == 2)

        await transmitter.flush()

        let countAfter = await cache.count()
        #expect(countAfter == 2)

        MockURLProtocol.reset()
    }

    @Test
    func flushWithEmptyCacheDoesNothing() async {
        let config = TelemetryDeck.Config(
            appID: "test-app",
            namespace: "test"
        )
        let cache = InMemoryEventCache()

        let transmitCallCount = Locked<Int>(0)
        MockURLProtocol.setResponseHandler { request in
            transmitCallCount.withLock { $0 += 1 }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (response, nil)
        }

        let session = createMockURLSession()
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            urlSession: session
        )

        await transmitter.flush()

        let callCount = transmitCallCount.withLock { $0 }
        #expect(callCount == 0)

        MockURLProtocol.reset()
    }
}

private final class Locked<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
