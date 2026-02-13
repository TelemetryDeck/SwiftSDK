import Foundation

/// Transmits events to the TelemetryDeck API on a repeating timer, retrying failed events via the cache.
public actor DefaultEventTransmitter: EventTransmitting {
    private let configuration: TelemetryDeck.Config
    private let cache: any EventCaching
    private let logger: any Logging
    private let urlSession: URLSession
    private var transmitTask: Task<Void, Never>?
    private let transmitInterval: TimeInterval = 10

    /// Creates a transmitter with the given configuration, cache, logger, and URL session.
    public init(
        configuration: TelemetryDeck.Config,
        cache: any EventCaching,
        logger: any Logging,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.cache = cache
        self.logger = logger
        self.urlSession = urlSession
    }

    /// Starts the repeating transmission timer.
    public func start() {
        guard transmitTask == nil else { return }
        transmitTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.transmitBatch()
                let interval = self?.transmitInterval ?? 10
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
            let (_, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                return events
            }
            return []
        } catch {
            return events
        }
    }

    /// Immediately transmits all cached events without waiting for the next timer tick.
    public func flush() async {
        await transmitBatch()
    }

    private func transmitBatch() async {
        let events = await cache.pop()
        guard !events.isEmpty else { return }
        let failed = await transmit(events)
        for event in failed {
            await cache.add(event)
        }
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
