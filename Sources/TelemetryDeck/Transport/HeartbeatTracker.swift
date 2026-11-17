import Foundation

actor HeartbeatTracker {
    private let uptime: @Sendable () -> TimeInterval
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let isAppActive: @Sendable () async -> Bool
    private let lifecycleEvents: @Sendable () -> AsyncStream<LifecycleEvent>

    private var emitter: (any EventSending)?
    private var interval: TimeInterval?
    private var accumulatedActiveTime: TimeInterval = 0
    private var activeSince: TimeInterval?
    private var stateGeneration = 0
    private var lifecycleTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    init(
        uptime: @escaping @Sendable () -> TimeInterval = HeartbeatTracker.systemUptime,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = HeartbeatTracker.systemSleep,
        isAppActive: @escaping @Sendable () async -> Bool = AppActivity.isActive,
        lifecycleEvents: @escaping @Sendable () -> AsyncStream<LifecycleEvent> = LifecycleNotifier.events
    ) {
        self.uptime = uptime
        self.sleep = sleep
        self.isAppActive = isAppActive
        self.lifecycleEvents = lifecycleEvents
    }

    static func systemUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    static func systemSleep(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    var isRunning: Bool {
        interval != nil
    }

    func start(emitter: any EventSending) {
        self.emitter = emitter
    }

    func stop() {
        stopHeartbeats()
        emitter = nil
    }

    func startHeartbeats(_ frequency: TelemetryDeck.HeartbeatFrequency) async {
        guard emitter != nil, interval == nil else { return }
        interval = frequency.interval
        accumulatedActiveTime = 0
        stateGeneration += 1
        let generation = stateGeneration
        lifecycleTask = LifecycleSubscription.start(
            events: lifecycleEvents(),
            onBackground: { await self.handleBackground() },
            onForeground: { await self.handleForeground() }
        )
        let isActive = await isAppActive()
        guard isActive, stateGeneration == generation else { return }
        handleForeground()
    }

    func stopHeartbeats() {
        stateGeneration += 1
        lifecycleTask?.cancel()
        lifecycleTask = nil
        timerTask?.cancel()
        timerTask = nil
        interval = nil
        activeSince = nil
        accumulatedActiveTime = 0
    }

    func handleForeground() {
        stateGeneration += 1
        guard interval != nil, activeSince == nil else { return }
        activeSince = uptime()
        scheduleNextHeartbeat()
    }

    func handleBackground() async {
        stateGeneration += 1
        guard let interval, let since = activeSince else { return }
        timerTask?.cancel()
        timerTask = nil
        activeSince = nil
        let totalActiveTime = accumulatedActiveTime + Self.elapsed(from: since, to: uptime())
        guard totalActiveTime >= interval else {
            accumulatedActiveTime = totalActiveTime
            return
        }
        accumulatedActiveTime = Self.activeTimeCarriedOver(after: totalActiveTime, interval: interval)
        await sendHeartbeat()
    }

    private func scheduleNextHeartbeat() {
        guard let interval, activeSince != nil, timerTask == nil else { return }
        let delay = max(0, interval - accumulatedActiveTime)
        timerTask = Task { [sleep] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            await self.heartbeatDue()
        }
    }

    private func heartbeatDue() async {
        guard !Task.isCancelled, let interval, let since = activeSince else { return }
        timerTask = nil
        let now = uptime()
        let totalActiveTime = accumulatedActiveTime + Self.elapsed(from: since, to: now)
        activeSince = now
        guard totalActiveTime >= interval else {
            accumulatedActiveTime = totalActiveTime
            scheduleNextHeartbeat()
            return
        }
        accumulatedActiveTime = Self.activeTimeCarriedOver(after: totalActiveTime, interval: interval)
        await sendHeartbeat()
        scheduleNextHeartbeat()
    }

    private func sendHeartbeat() async {
        await emitter?.send(EventInput(DefaultEvents.Session.heartbeat.rawValue, skipsReservedPrefixValidation: true))
    }

    /// Returns the active time that counts toward the next heartbeat once a heartbeat has been sent for `totalActiveTime`.
    ///
    /// Time beyond the interval is kept, so late timer wakes do not lose active time. When two or more intervals have
    /// passed, the tracker was suspended rather than late, and the excess is dropped to avoid catch-up heartbeats.
    private static func activeTimeCarriedOver(after totalActiveTime: TimeInterval, interval: TimeInterval) -> TimeInterval {
        assert(interval > 0 && totalActiveTime >= interval)
        let excess = totalActiveTime - interval
        return excess < interval ? excess : 0
    }

    private static func elapsed(from start: TimeInterval, to end: TimeInterval) -> TimeInterval {
        max(0, end - start)
    }
}
