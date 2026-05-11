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
    private var consecutiveFailures: Int = 0

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
        maxBackoffInterval: TimeInterval = 300
    ) {
        self.configuration = configuration
        self.cache = cache
        self.logger = logger
        self.httpClient = httpClient
        self.transmitInterval = transmitInterval
        self.maxBackoffInterval = maxBackoffInterval
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

        guard let body = try? JSONEncoder.telemetryEncoder.encode(events) else {
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
            guard (200...299).contains(http.statusCode) else {
                logger.log(.error, "Transmit failed with HTTP \(http.statusCode), retrying \(events.count) events")
                return events
            }
            logger.log(.debug, "Transmitted \(events.count) events (HTTP \(http.statusCode))")
            return []
        } catch {
            logger.log(.error, "Transmit failed: \(error.localizedDescription), retrying \(events.count) events")
            return events
        }
    }

    /// Immediately transmits all cached events without waiting for the next timer tick, resets the backoff counter to 0 before transmitting.
    public func flush() async {
        consecutiveFailures = 0
        await transmitBatch()
    }

    private func transmitBatch() async {
        let events = await cache.pop()
        guard !events.isEmpty else { return }
        let remainingCount = await cache.count()
        logger.log(.info, "Sending \(events.count) events, \(remainingCount) remain in cache")
        let failed = await transmit(events)
        if failed.isEmpty {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            for event in failed {
                await cache.add(event)
            }
        }
    }

    /// Returns the current consecutive failure count, used by tests to verify backoff state.
    func currentBackoffFailures() -> Int {
        consecutiveFailures
    }

    private func nextInterval() -> TimeInterval {
        guard consecutiveFailures > 0 else { return transmitInterval }
        // Clamp the exponent to 16 to guard against overflow in pow()
        let multiplier = pow(2.0, Double(min(consecutiveFailures, 16)))
        return min(transmitInterval * multiplier, maxBackoffInterval)
    }

    private var serviceURL: URL? {
        var base = configuration.apiBaseURL.absoluteString
        if !base.hasSuffix("/") {
            base += "/"
        }
        let url = URL(string: base + "v2/namespace/\(configuration.namespace)/")
        assert(url != nil, "Failed to construct service URL from base: \(configuration.apiBaseURL)")
        return url
    }
}
