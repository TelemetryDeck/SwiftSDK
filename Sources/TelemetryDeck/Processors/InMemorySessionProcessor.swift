import Foundation

/// A session processor that keeps state entirely in memory.
///
public actor InMemorySessionProcessor: EventProcessor, SessionManaging {
    private let sendSessionStartedEvent: Bool
    private let dateProvider: DateProvider

    private var currentSession: UUID
    private var backgroundDate: Date?
    private var lifecycleTask: Task<Void, Never>?
    private var emitter: (any EventSending)?

    /// Creates a session processor that keeps state in memory only.
    public init(sendSessionStartedEvent: Bool = true) {
        self.sendSessionStartedEvent = sendSessionStartedEvent
        self.dateProvider = .system
        self.currentSession = UUID()
    }

    init(sendSessionStartedEvent: Bool = true, dateProvider: DateProvider) {
        self.sendSessionStartedEvent = sendSessionStartedEvent
        self.dateProvider = dateProvider
        self.currentSession = UUID()
    }

    /// Returns the identifier of the current session.
    public func currentSessionID() async -> UUID {
        currentSession
    }

    /// Generates a new session identifier and emits a session-started event if configured.
    @discardableResult
    public func startNewSession() async -> UUID {
        let newID = UUID()
        currentSession = newID
        if sendSessionStartedEvent {
            await emitSessionStarted()
        }
        return newID
    }

    /// Subscribes to app lifecycle events and emits a session-started event if configured.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        self.emitter = emitter

        lifecycleTask = LifecycleSubscription.start(
            onBackground: { await self.handleBackground() },
            onForeground: { await self.handleForeground() }
        )

        if sendSessionStartedEvent {
            await emitSessionStarted()
        }
    }

    /// Cancels the lifecycle subscription and releases the event emitter reference.
    public func stop() async {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        emitter = nil
    }

    /// Attaches the current session identifier to the event context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.sessionID = currentSession
        return try await next(input, context)
    }

    func handleBackground() {
        backgroundDate = dateProvider.now()
    }

    func handleForeground() async {
        guard let bgDate = backgroundDate,
            dateProvider.now().timeIntervalSince(bgDate) > SessionConstants.backgroundThreshold
        else {
            backgroundDate = nil
            return
        }
        backgroundDate = nil
        currentSession = UUID()
        if sendSessionStartedEvent {
            await emitSessionStarted()
        }
    }

    private func emitSessionStarted() async {
        await emitter?.send(EventInput(DefaultEvents.Session.started.rawValue, skipsReservedPrefixValidation: true))
    }
}
