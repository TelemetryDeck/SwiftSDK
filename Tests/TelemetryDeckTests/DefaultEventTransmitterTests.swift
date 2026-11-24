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

private func makeTransmitter(cache: any EventCaching, client: ScriptedHTTPClient) -> DefaultEventTransmitter {
    DefaultEventTransmitter(
        configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
        cache: cache,
        logger: NoOpLogger(),
        httpClient: client
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
            #expect(url.absoluteString == "https://api.example.com/v3/\(namespace)/")
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
            #expect(url.absoluteString == "https://example.com/array/sensors/v3/\(namespace)/")
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
            #expect(url.absoluteString == "https://example.com/array/sensors/v3/\(namespace)/")
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

    @Test(arguments: [400, 401, 403, 404, 413, 422, 501, 505])
    func transmitDropsEventsForNonRetryableStatusCode(statusCode: Int) async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: statusCode, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.isEmpty, "Status \(statusCode) should drop events, not retry")
    }

    @Test(arguments: [408, 429, 500, 502, 503, 504])
    func transmitRetriesEventsForRetryableStatusCode(statusCode: Int) async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: statusCode, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        let events = [createTestEvent()]
        let failed = await transmitter.transmit(events)

        #expect(failed.count == events.count, "Status \(statusCode) should retry events")
    }

    @Test
    func dropStatusCodeResetsBackoffCounter() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let switchableStub = SwitchableHTTPClient(initialStatusCode: 500, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: switchableStub
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        let failuresAfterRetry = await transmitter.currentBackoffFailures()
        #expect(failuresAfterRetry == 1)

        switchableStub.statusCode = 403
        await transmitter.flush()
        let failuresAfterDrop = await transmitter.currentBackoffFailures()
        #expect(failuresAfterDrop == 0)

        let remaining = await cache.count()
        #expect(remaining == 0)
    }

    @Test
    func flushDropsEventsOnNonRetryableStatus() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 401, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        await cache.add(createTestEvent(type: "event.one"))
        await cache.add(createTestEvent(type: "event.two"))

        await transmitter.flush()

        let countAfter = await cache.count()
        #expect(countAfter == 0)
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
    func flushSendsEveryBatchInCache() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = SequencedHTTPClient(statusCodes: [200])

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        for _ in 0..<250 {
            await cache.add(createTestEvent())
        }

        await transmitter.flush()

        #expect(await cache.count() == 0)
        #expect(stub.requestCount == 3)
    }

    @Test
    func flushStopsAtFirstFailedBatch() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = SequencedHTTPClient(statusCodes: [200, 503])

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        for _ in 0..<250 {
            await cache.add(createTestEvent())
        }

        await transmitter.flush()

        #expect(await cache.count() == 150)
        #expect(stub.requestCount == 2)
        #expect(await transmitter.currentBackoffFailures() == 1)
    }

    @Test
    func flushSendsNothingWhenTaskIsAlreadyCancelled() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = SequencedHTTPClient(statusCodes: [200])

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        for _ in 0..<250 {
            await cache.add(createTestEvent())
        }

        await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await transmitter.flush()
        }.value

        #expect(await cache.count() == 250)
        #expect(stub.requestCount == 0)
    }

    @Test
    func flushContinuesPastBatchRejectedByServer() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = SequencedHTTPClient(statusCodes: [400, 200])

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        for _ in 0..<150 {
            await cache.add(createTestEvent())
        }

        await transmitter.flush()

        #expect(await cache.count() == 0)
        #expect(stub.requestCount == 2)
    }

    @Test
    func consecutiveFailuresIncrementOnFailedBatch() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(statusCode: 500, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        // Each flush() resets consecutiveFailures before transmitting, so a single failed flush leaves it at 1.
        await cache.add(createTestEvent())
        await transmitter.flush()

        let failuresAfterOne = await transmitter.currentBackoffFailures()
        #expect(failuresAfterOne == 1)

        // The re-queued failed event is still in the cache; flush resets then the batch fails again → 1.
        await transmitter.flush()

        let failuresAfterTwo = await transmitter.currentBackoffFailures()
        #expect(failuresAfterTwo == 1)
    }

    @Test
    func consecutiveFailuresResetOnSuccess() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let switchableStub = SwitchableHTTPClient(initialStatusCode: 500, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: switchableStub
        )

        // Flush with failure: reset to 0, then fail → 1.
        await cache.add(createTestEvent())
        await transmitter.flush()

        let failuresBefore = await transmitter.currentBackoffFailures()
        #expect(failuresBefore == 1)

        // Switch to success: flush resets to 0, then batch succeeds → stays 0.
        switchableStub.statusCode = 200
        await transmitter.flush()

        let failuresAfter = await transmitter.currentBackoffFailures()
        #expect(failuresAfter == 0)
    }

    @Test(arguments: [(200, 0, 0), (503, 2, 1)])
    func stoppingDuringSendLetsTheRequestComplete(statusCode: Int, cachedCount: Int, failures: Int) async throws {
        let cache = InMemoryEventCache()
        let client = ScriptedHTTPClient()
        let transmitter = makeTransmitter(cache: cache, client: client)
        await cache.add(createTestEvent(type: "event.one"))
        await cache.add(createTestEvent(type: "event.two"))

        await transmitter.start()
        await client.waitForRequests(1)
        let stopping = Task { await transmitter.stop() }
        client.respond(statusCode: statusCode)
        await stopping.value

        #expect(client.cancelledRequestCount == 0)
        #expect(try client.sentEventTypes() == [["event.one", "event.two"]])
        #expect(await cache.count() == cachedCount)
        #expect(await transmitter.currentBackoffFailures() == failures)
    }

    @Test
    func flushJoinsTheBatchInFlightAndSendsEachEventOnce() async throws {
        let cache = InMemoryEventCache()
        let client = ScriptedHTTPClient()
        let transmitter = makeTransmitter(cache: cache, client: client)
        for index in 0..<150 {
            await cache.add(createTestEvent(type: "event.\(index)"))
        }

        await transmitter.start()
        await client.waitForRequests(1)
        let flush = Task { await transmitter.flush() }
        client.respond(statusCode: 200)
        client.respond(statusCode: 200)
        await flush.value
        await transmitter.stop()

        let sent = try client.sentEventTypes()
        #expect(sent.map(\.count) == [100, 50])
        #expect(Set(sent.joined()).count == 150)
        #expect(await cache.count() == 0)
    }

    @Test
    func flushFromCancelledTaskLetsTheRequestInFlightCompleteAndStartsNoFurtherBatch() async throws {
        let cache = InMemoryEventCache()
        let client = ScriptedHTTPClient()
        let transmitter = makeTransmitter(cache: cache, client: client)
        for _ in 0..<150 {
            await cache.add(createTestEvent())
        }

        let flush = Task { await transmitter.flush() }
        await client.waitForRequests(1)
        flush.cancel()
        client.respond(statusCode: 200)
        await flush.value

        #expect(client.cancelledRequestCount == 0)
        #expect(try client.sentEventTypes().map(\.count) == [100])
        #expect(await cache.count() == 50)
    }

    @Test
    func transmitFromCancelledTaskDoesNotCancelTheRequest() async {
        let client = ScriptedHTTPClient()
        let transmitter = makeTransmitter(cache: InMemoryEventCache(), client: client)

        let transmit = Task { await transmitter.transmit([createTestEvent()]) }
        await client.waitForRequests(1)
        transmit.cancel()
        client.respond(statusCode: 200)

        #expect(await transmit.value.isEmpty)
        #expect(client.cancelledRequestCount == 0)
    }

    @Test
    func failedSendFromTimerCountsAFailure() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let logger = SpyLogger()
        let stub = StubHTTPClient(error: URLError(.notConnectedToInternet))
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: logger,
            httpClient: stub
        )
        await cache.add(createTestEvent())

        await transmitter.start()
        for _ in 0..<250 {
            if await transmitter.currentBackoffFailures() > 0 { break }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        await transmitter.stop()

        #expect(await transmitter.currentBackoffFailures() == 1)
        #expect(await cache.count() == 1)
        #expect(logger.hasErrorContaining("Transmit failed"))
    }

    @Test
    func flushResetsConsecutiveFailures() async {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let cache = InMemoryEventCache()
        let failingStub = StubHTTPClient(statusCode: 503, url: URL(string: "https://nom.telemetrydeck.com")!)

        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: cache,
            logger: DefaultLogger(),
            httpClient: failingStub
        )

        // Flush with failure leaves consecutiveFailures at 1.
        await cache.add(createTestEvent())
        await transmitter.flush()

        let failuresBefore = await transmitter.currentBackoffFailures()
        #expect(failuresBefore == 1)

        // Flush with an empty cache: the reset fires, transmitBatch exits early (no events),
        // so consecutiveFailures ends at 0.
        _ = await cache.pop()

        await transmitter.flush()

        let failuresAfter = await transmitter.currentBackoffFailures()
        #expect(failuresAfter == 0)
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

    @Test
    func transmitSendsFlatEventObjects() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "test.event",
            clientUser: "test-user",
            sessionID: nil,
            receivedAt: Date(timeIntervalSince1970: 1_609_459_200.5),
            payload: [
                "text": "value",
                "count": 3,
                "ratio": 0.5,
                "flag": true,
                "list": .array(["a", "b"]),
                "type": "spoofed",
                "appID": "spoofed",
                "clientUser": "spoofed",
                "receivedAt": "spoofed",
                "isTestMode": "true",
                "sessionID": "spoofed",
                "floatValue": 1.0,
            ],
            floatValue: nil,
            isTestMode: false
        )

        _ = await transmitter.transmit([event])

        let sent = try sentEvents(stub.lastRequest)
        #expect(sent.count == 1)
        let fields = try #require(sent.first)
        #expect(fields["payload"] == nil)
        #expect(fields["text"] as? String == "value")
        #expect(fields["count"] as? Int == 3)
        #expect(fields["ratio"] as? Double == 0.5)
        #expect(fields["flag"] as? Bool == true)
        #expect(fields["list"] as? [String] == ["a", "b"])
        #expect(fields["type"] as? String == "test.event")
        #expect(fields["appID"] as? String == "test-app-id")
        #expect(fields["clientUser"] as? String == "test-user")
        #expect(fields["receivedAt"] as? String == "2021-01-01T00:00:00.500Z")
        #expect(fields["isTestMode"] as? String == "false")
        #expect(fields["sessionID"] == nil)
        #expect(fields["floatValue"] == nil)
        #expect(fields.count == 10)
    }

    @Test
    func transmitSendsSessionIDAndFloatValueWhenPresent() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "test.event",
            clientUser: "test-user",
            sessionID: "test-session",
            receivedAt: Date(),
            payload: [:],
            floatValue: 42.5,
            isTestMode: true
        )

        _ = await transmitter.transmit([event])

        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["sessionID"] as? String == "test-session")
        #expect(fields["floatValue"] as? Double == 42.5)
        #expect(fields["isTestMode"] as? String == "true")
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func transmitOmitsNonFiniteFloatValue(floatValue: Double) async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "test.event",
            clientUser: "test-user",
            sessionID: "test-session",
            receivedAt: Date(),
            payload: [:],
            floatValue: floatValue,
            isTestMode: false
        )

        let failed = await transmitter.transmit([event])

        #expect(failed.isEmpty)
        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["floatValue"] == nil)
    }

    @Test
    func transmitReplacesCharactersTheServerRejects() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "Login Clicked:now",
            clientUser: "test-user",
            sessionID: "test-session",
            receivedAt: Date(),
            payload: [
                "Purchase Type": "a",
                "screen/name": "b",
                "Größe": "c",
                "Valid.key_1-2": "d",
                "": "e",
            ],
            floatValue: nil,
            isTestMode: false
        )

        _ = await transmitter.transmit([event])

        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["type"] as? String == "Login_Clicked_now")
        #expect(fields["Purchase_Type"] as? String == "a")
        #expect(fields["screen_name"] as? String == "b")
        #expect(fields["Gr__e"] as? String == "c")
        #expect(fields["Valid.key_1-2"] as? String == "d")
        #expect(fields[""] == nil)
        #expect(fields.keys.allSatisfy(IngestIdentifier.isValid))
    }

    @Test
    func transmitKeepsValidKeyWhenRewrittenKeyCollides() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "test.event",
            clientUser: "test-user",
            sessionID: "test-session",
            receivedAt: Date(),
            payload: ["a b": "rewritten-space", "a_b": "valid", "a:b": "rewritten-colon", "c d": "first", "c:d": "second"],
            floatValue: nil,
            isTestMode: false
        )

        _ = await transmitter.transmit([event])

        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["a_b"] as? String == "valid")
        #expect(fields["c_d"] as? String == "first")
    }

    @Test
    func transmitOmitsTypeForEmptyEventName() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: config,
            cache: InMemoryEventCache(),
            logger: DefaultLogger(),
            httpClient: stub
        )
        let event = Event(
            appID: "test-app-id",
            type: "",
            clientUser: "test-user",
            sessionID: "test-session",
            receivedAt: Date(),
            payload: ["type": "spoofed"],
            floatValue: nil,
            isTestMode: false
        )

        _ = await transmitter.transmit([event])

        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["type"] == nil)
    }

    @Test
    func transmitSendsEventsRestoredFromDiskCacheAsFlatObjects() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-restore-transmit-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let writerCache = DefaultEventCache(fileURL: fileURL)
        await writerCache.add(createTestEvent(type: "restored.event"))
        await writerCache.persist()

        let cache = DefaultEventCache(fileURL: fileURL)
        await cache.restore()
        let stub = StubHTTPClient(statusCode: 200, url: URL(string: "https://nom.telemetrydeck.com")!)
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub
        )

        await transmitter.flush()

        let fields = try #require(try sentEvents(stub.lastRequest).first)
        #expect(fields["payload"] == nil)
        #expect(fields["type"] as? String == "restored.event")
        #expect(fields["key"] as? String == "value")
        #expect(await cache.count() == 0)
    }

    @Test(arguments: [429, 503])
    func retryAfterPausesFlushUntilElapsed(statusCode: Int) async {
        let clock = MutableClock()
        let cache = InMemoryEventCache()
        let stub = SwitchableHTTPClient(
            initialStatusCode: statusCode,
            url: URL(string: "https://nom.telemetrydeck.com")!,
            headerFields: ["Retry-After": "5"]
        )
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub,
            dateProvider: clock.dateProvider
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        #expect(await cache.count() == 1)

        stub.statusCode = 200
        stub.headerFields = nil
        clock.advance(by: 4.9)
        await transmitter.flush()
        #expect(await cache.count() == 1)

        clock.advance(by: 0.1)
        await transmitter.flush()
        #expect(await cache.count() == 0)
    }

    @Test
    func retryAfterExtendsTimerInterval() async {
        let clock = MutableClock()
        let cache = InMemoryEventCache()
        let stub = StubHTTPClient(
            statusCode: 503,
            url: URL(string: "https://nom.telemetrydeck.com")!,
            headerFields: ["Retry-After": "120"]
        )
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub,
            transmitInterval: 10,
            maxBackoffInterval: 300,
            dateProvider: clock.dateProvider
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        #expect(await transmitter.nextInterval() == 120)

        clock.advance(by: 110)
        #expect(await transmitter.nextInterval() == 20)
    }

    @Test
    func retryAfterPauseIsBoundedWhenClockMovesBack() async {
        let clock = MutableClock()
        let cache = InMemoryEventCache()
        let stub = SwitchableHTTPClient(
            initialStatusCode: 503,
            url: URL(string: "https://nom.telemetrydeck.com")!,
            headerFields: ["Retry-After": "5"]
        )
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub,
            transmitInterval: 10,
            maxBackoffInterval: 300,
            dateProvider: clock.dateProvider
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        clock.advance(by: -86_400)
        #expect(await transmitter.nextInterval() == 300)
    }

    @Test(arguments: [nil, "", "abc", "0", "-5", "1e400", "Wed, 21 Oct 2015 07:28:00 GMT"] as [String?])
    func retryAfterIgnoredWhenMissingOrInvalid(header: String?) async {
        let clock = MutableClock()
        let cache = InMemoryEventCache()
        let stub = SwitchableHTTPClient(
            initialStatusCode: 503,
            url: URL(string: "https://nom.telemetrydeck.com")!,
            headerFields: header.map { ["Retry-After": $0] }
        )
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub,
            transmitInterval: 10,
            dateProvider: clock.dateProvider
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        #expect(await transmitter.nextInterval() == 20)

        stub.statusCode = 200
        await transmitter.flush()
        #expect(await cache.count() == 0)
    }

    @Test
    func retryAfterIsBoundedByMaxBackoffInterval() async {
        let header = "99999999999999999999999"
        let clock = MutableClock()
        let cache = InMemoryEventCache()
        let stub = SwitchableHTTPClient(
            initialStatusCode: 503,
            url: URL(string: "https://nom.telemetrydeck.com")!,
            headerFields: ["Retry-After": header]
        )
        let transmitter = DefaultEventTransmitter(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            cache: cache,
            logger: DefaultLogger(),
            httpClient: stub,
            transmitInterval: 10,
            maxBackoffInterval: 300,
            dateProvider: clock.dateProvider
        )

        await cache.add(createTestEvent())
        await transmitter.flush()
        #expect(await transmitter.nextInterval() == 300)

        stub.statusCode = 200
        clock.advance(by: 300)
        await transmitter.flush()
        #expect(await cache.count() == 0)
    }
}

private func sentEvents(_ request: URLRequest?) throws -> [[String: Any]] {
    let body = try #require(request?.httpBody)
    return try #require(try JSONSerialization.jsonObject(with: body) as? [[String: Any]])
}

private final class StubHTTPClient: HTTPDataLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastRequest: URLRequest?

    private let result: Result<(Data, URLResponse), Error>
    private let onRequest: (() -> Void)?

    init(statusCode: Int, url: URL, headerFields: [String: String]? = nil, onRequest: (() -> Void)? = nil) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
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

private final class SwitchableHTTPClient: HTTPDataLoader, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var _statusCode: Int
    private var _headerFields: [String: String]?

    var statusCode: Int {
        get { lock.withLock { _statusCode } }
        set { lock.withLock { _statusCode = newValue } }
    }

    var headerFields: [String: String]? {
        get { lock.withLock { _headerFields } }
        set { lock.withLock { _headerFields = newValue } }
    }

    init(initialStatusCode: Int, url: URL, headerFields: [String: String]? = nil) {
        self._statusCode = initialStatusCode
        self._headerFields = headerFields
        self.url = url
    }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        let (code, headers) = lock.withLock { (_statusCode, _headerFields) }
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers)!
        return (Data(), response)
    }
}

/// Answers each request with the next status code, repeating the last one when they run out.
private final class SequencedHTTPClient: HTTPDataLoader, @unchecked Sendable {
    private let statusCodes: [Int]
    private let count = Locked<Int>(0)

    var requestCount: Int {
        count.withLock { $0 }
    }

    init(statusCodes: [Int]) {
        self.statusCodes = statusCodes
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = count.withLock { value in
            defer { value += 1 }
            return value
        }
        let code = statusCodes[min(index, statusCodes.count - 1)]
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
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
