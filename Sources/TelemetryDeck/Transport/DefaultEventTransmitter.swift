import Foundation

/// Transmits events to the TelemetryDeck API on a repeating timer, retrying failed events via the cache.
public actor DefaultEventTransmitter: EventTransmitting {
    private let configuration: TelemetryDeck.Config
    private let cache: any EventCaching
    private let logger: any Logging
    private let httpClient: any HTTPDataLoader
    private var transmitTask: Task<Void, Never>?
    private let transmitInterval: TimeInterval
    private let maxBackoffInterval: TimeInterval
    private let dateProvider: DateProvider
    private var consecutiveFailures: Int = 0
    private var pausedUntil: Date?

    /// Creates a transmitter with the given configuration, cache, logger, and URL session.
    public init(
        configuration: TelemetryDeck.Config,
        cache: any EventCaching,
        logger: any Logging,
        urlSession: URLSession = .shared,
        transmitInterval: TimeInterval = 10,
        maxBackoffInterval: TimeInterval = 300
    ) {
        self.init(
            configuration: configuration,
            cache: cache,
            logger: logger,
            httpClient: urlSession,
            transmitInterval: transmitInterval,
            maxBackoffInterval: maxBackoffInterval
        )
    }

    init(
        configuration: TelemetryDeck.Config,
        cache: any EventCaching,
        logger: any Logging,
        httpClient: any HTTPDataLoader,
        transmitInterval: TimeInterval = 10,
        maxBackoffInterval: TimeInterval = 300,
        dateProvider: DateProvider = .system
    ) {
        self.configuration = configuration
        self.cache = cache
        self.logger = logger
        self.httpClient = httpClient
        self.transmitInterval = transmitInterval
        self.maxBackoffInterval = maxBackoffInterval
        self.dateProvider = dateProvider
    }

    /// Starts the repeating transmission timer.
    public func start() {
        guard transmitTask == nil else { return }
        transmitTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.transmitBatch()
                let interval = await self?.nextInterval() ?? 10
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Cancels the repeating transmission timer.
    public func stop() {
        transmitTask?.cancel()
        transmitTask = nil
    }

    /// Sends the given events to the API, returning any that could not be delivered.
    public func transmit(_ events: [Event]) async -> [Event] {
        guard let url = serviceURL else { return events }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let timestampFormatter = Formatter.iso8601
        guard let body = try? JSONEncoder().encode(events.map { $0.ingestFields(timestampFormatter: timestampFormatter) }) else {
            logger.log(.error, "Failed to encode \(events.count) events, dropping batch")
            assertionFailure("Failed to encode events for transmission")
            return []
        }
        request.httpBody = body

        do {
            let (_, response) = try await httpClient.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                logger.log(.error, "Transmit failed: response was not HTTP, retrying \(events.count) events")
                return events
            }
            switch http.disposition {
            case .success:
                logger.log(.debug, "Transmitted \(events.count) events (HTTP \(http.statusCode))")
                return []
            case .drop(let reason):
                logger.log(.error, "Dropping \(events.count) events: rejected by server — \(reason)")
                return []
            case .retry:
                logger.log(.error, "Transmit failed with HTTP \(http.statusCode), retrying \(events.count) events")
                if let delay = http.retryAfter(maximum: maxBackoffInterval) {
                    pausedUntil = dateProvider.now().addingTimeInterval(delay)
                    logger.log(.info, "Server asked to retry after \(delay) seconds, pausing transmission")
                }
                return events
            }
        } catch {
            logger.log(.error, "Transmit failed: \(error.localizedDescription), retrying \(events.count) events")
            return events
        }
    }

    /// Immediately transmits all cached events without waiting for the next timer tick, resets the backoff counter to 0 before transmitting.
    ///
    /// Stops at the first batch that fails. Its events go back into the cache, so continuing would only retry them while offline.
    /// Respects `Retry-After` server header.
    public func flush() async {
        consecutiveFailures = 0
        while !Task.isCancelled, await transmitBatch() {}
    }

    /// Transmits one batch from the cache, returning `false` if the cache was empty or the batch failed.
    @discardableResult
    private func transmitBatch() async -> Bool {
        let pause = remainingPause()
        guard pause == 0 else {
            logger.log(.debug, "Transmission paused for \(pause) more seconds")
            return false
        }
        let events = await cache.pop()
        guard !events.isEmpty else { return false }
        let remainingCount = await cache.count()
        logger.log(.info, "Sending \(events.count) events, \(remainingCount) remain in cache")
        let failed = await transmit(events)
        if failed.isEmpty {
            consecutiveFailures = 0
            return true
        } else {
            consecutiveFailures += 1
            for event in failed {
                await cache.add(event)
            }
            return false
        }
    }

    /// Returns the current consecutive failure count, used by tests to verify backoff state.
    func currentBackoffFailures() -> Int {
        consecutiveFailures
    }

    func nextInterval() -> TimeInterval {
        max(backoffInterval(), remainingPause())
    }

    private func backoffInterval() -> TimeInterval {
        guard consecutiveFailures > 0 else { return transmitInterval }
        // Clamp the exponent to 16 to guard against overflow in pow()
        let multiplier = pow(2.0, Double(min(consecutiveFailures, 16)))
        return min(transmitInterval * multiplier, maxBackoffInterval)
    }

    private func remainingPause() -> TimeInterval {
        guard let pausedUntil else { return 0 }
        return min(max(0, pausedUntil.timeIntervalSince(dateProvider.now())), maxBackoffInterval)
    }

    private var serviceURL: URL? {
        var base = configuration.apiBaseURL.absoluteString
        if !base.hasSuffix("/") {
            base += "/"
        }
        let url = URL(string: base + "v3/\(configuration.namespace)/")
        assert(url != nil, "Failed to construct service URL from base: \(configuration.apiBaseURL)")
        return url
    }
}

private enum ResponseDisposition {
    case success
    case drop(reason: String)
    case retry
}

extension HTTPURLResponse {
    fileprivate var disposition: ResponseDisposition {
        if (200...299).contains(statusCode) {
            return .success
        }
        switch statusCode {
        case 400: return .drop(reason: "Bad Request (400)")
        case 401: return .drop(reason: "Unauthorized (401)")
        case 403: return .drop(reason: "Forbidden (403)")
        case 404: return .drop(reason: "Not Found (404)")
        case 413: return .drop(reason: "Payload Too Large (413)")
        case 422: return .drop(reason: "Unprocessable Entity (422)")
        case 501: return .drop(reason: "Not Implemented (501)")
        case 505: return .drop(reason: "HTTP Version Not Supported (505)")
        default: return .retry
        }
    }

    fileprivate func retryAfter(maximum: TimeInterval) -> TimeInterval? {
        guard let header = value(forHTTPHeaderField: "Retry-After"),
            let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)),
            seconds.isFinite,
            seconds > 0
        else { return nil }
        return min(seconds, maximum)
    }
}

extension Event {
    fileprivate func ingestFields(timestampFormatter: ISO8601DateFormatter) -> [String: PayloadValue] {
        var fields: [String: PayloadValue] = [:]
        for (key, value) in payload where IngestIdentifier.isValid(key) {
            fields[key] = value
        }
        for (key, value) in payload.sorted(by: { $0.key < $1.key }) where !IngestIdentifier.isValid(key) {
            let ingestKey = IngestIdentifier.sanitized(key)
            guard !ingestKey.isEmpty, fields[ingestKey] == nil else { continue }
            fields[ingestKey] = value
        }
        let ingestType = IngestIdentifier.sanitized(type)
        fields["type"] = ingestType.isEmpty ? nil : .string(ingestType)
        fields["appID"] = .string(appID)
        fields["clientUser"] = .string(clientUser)
        fields["sessionID"] = sessionID.map(PayloadValue.string)
        fields["receivedAt"] = .string(timestampFormatter.string(from: receivedAt))
        fields["floatValue"] = floatValue.flatMap { $0.isFinite ? .double($0) : nil }
        fields["isTestMode"] = .string(isTestMode)
        return fields
    }
}
