import Foundation

/// Manages session identity, retention metrics, and new-install detection.
public actor SessionTrackingProcessor: EventProcessor, SessionManaging {
    private struct StoredSession: Codable {
        let startedAt: Date
        var durationInSeconds: Int

        private enum CodingKeys: String, CodingKey {
            case startedAt = "st"
            case durationInSeconds = "dn"
        }
    }

    private static let backgroundThreshold: TimeInterval = 5 * 60

    private let sendSessionStartedEvent: Bool

    private var currentSession: UUID
    private var backgroundDate: Date?
    private var lifecycleTask: Task<Void, Never>?

    private var storage: (any ProcessorStorage)?
    private var emitter: (any EventSending)?

    private var recentSessions: [StoredSession] = []
    private var deletedSessionsCount: Int = 0
    private var firstSessionDate: String?
    private var distinctDaysUsed: Set<String> = []

    private var currentSessionStart: Date?
    private var currentSessionPausedAt: Date?
    private var currentSessionAccumulatedSeconds: Int = 0

    private var isNewInstall = false

    private var pendingPersistTasks: [Task<Void, Never>] = []

    /// Creates a session tracking processor.
    public init(sendSessionStartedEvent: Bool = true) {
        self.sendSessionStartedEvent = sendSessionStartedEvent
        self.currentSession = UUID()
    }

    /// Returns the identifier of the current session.
    public func currentSessionID() async -> UUID {
        currentSession
    }

    /// Generates a new session identifier, records the session start, and emits a session-started event if configured.
    @discardableResult
    public func startNewSession() async -> UUID {
        let newID = UUID()
        currentSession = newID
        recordSessionStart()
        if sendSessionStartedEvent {
            await emitter?.send(EventInput(DefaultEvents.Session.started.rawValue, skipsReservedPrefixValidation: true))
        }
        return newID
    }

    /// Restores persisted state, subscribes to lifecycle events, and emits startup events.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        self.storage = storage
        self.emitter = emitter

        await V2DataMigrator.migrateIfNeeded(storage: storage)

        if let data = await storage.data(forKey: "recentSessions"),
            let sessions = try? JSONDecoder().decode([StoredSession].self, from: data)
        {
            recentSessions = sessions
        }

        deletedSessionsCount = await storage.integer(forKey: "deletedSessionsCount")
        firstSessionDate = await storage.string(forKey: "firstSessionDate")

        if let daysData = await storage.data(forKey: "distinctDaysUsed"),
            let days = try? JSONDecoder().decode(Set<String>.self, from: daysData)
        {
            distinctDaysUsed = days
        }

        cleanOldSessions()
        updateDistinctDays()

        let existingInstallID = await storage.string(forKey: "installID")
        if existingInstallID == nil {
            await storage.set(UUID().uuidString, forKey: "installID")
            isNewInstall = true
        }

        lifecycleTask = Task {
            for await event in LifecycleNotifier.events() {
                switch event {
                case .background:
                    handleBackground()
                case .foreground:
                    await handleForeground()
                case .termination:
                    break
                }
            }
        }

        recordSessionStart()

        if isNewInstall {
            let dateStr = firstSessionDate ?? dateString(from: Date())
            await emitter.send(
                EventInput(
                    DefaultEvents.Acquisition.newInstallDetected.rawValue,
                    parameters: [DefaultParams.Acquisition.firstSessionDate.rawValue: dateStr],
                    skipsReservedPrefixValidation: true
                )
            )
        }

        if sendSessionStartedEvent {
            await emitter.send(EventInput(DefaultEvents.Session.started.rawValue, skipsReservedPrefixValidation: true))
        }
    }

    /// Cancels the lifecycle subscription, awaits all pending persistence tasks, and releases the event emitter reference.
    public func stop() async {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        for task in pendingPersistTasks {
            await task.value
        }
        pendingPersistTasks.removeAll()
        emitter = nil
    }

    /// Attaches session identity, retention metrics, and new-install flag to the event context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.sessionID = currentSession

        if let firstDate = firstSessionDate {
            context.addParameter(DefaultParams.Acquisition.firstSessionDate, value: firstDate)
        }

        let totalCount = recentSessions.count + deletedSessionsCount
        context.addParameter(DefaultParams.Retention.totalSessionsCount, value: totalCount)
        context.addParameter(DefaultParams.Retention.distinctDaysUsed, value: distinctDaysUsed.count)

        let thirtyDaysAgo = dateString(from: Date().addingTimeInterval(-30 * 24 * 3600))
        let recentDays = distinctDaysUsed.filter { $0 >= thirtyDaysAgo }
        context.addParameter(DefaultParams.Retention.distinctDaysUsedLastMonth, value: recentDays.count)

        let completedSessions = currentSessionStart == nil ? recentSessions : Array(recentSessions.dropLast())
        let averageSessionSeconds: Int
        if completedSessions.isEmpty {
            averageSessionSeconds = -1
        } else {
            let totalSeconds = completedSessions.reduce(0) { $0 + $1.durationInSeconds }
            averageSessionSeconds = Int(Double(totalSeconds) / Double(completedSessions.count))
        }
        context.addParameter(DefaultParams.Retention.averageSessionSeconds, value: averageSessionSeconds)

        if recentSessions.count >= 2 {
            let previousSession = recentSessions[recentSessions.count - 2]
            context.addParameter(
                DefaultParams.Retention.previousSessionSeconds,
                value: previousSession.durationInSeconds
            )
        }

        let wasNewInstall = isNewInstall
        if wasNewInstall {
            context.addParameter(DefaultParams.Acquisition.isNewInstall, value: true)
        }

        let event = try await next(input, context)
        if wasNewInstall {
            isNewInstall = false
        }
        return event
    }

    private func schedulePersist(_ work: @Sendable @escaping () async -> Void) {
        pendingPersistTasks.removeAll { $0.isCancelled }
        pendingPersistTasks.append(Task { await work() })
    }

    private func recordSessionStart() {
        let now = Date()
        currentSessionStart = now
        currentSessionPausedAt = nil
        currentSessionAccumulatedSeconds = 0

        let dateStr = dateString(from: now)
        if firstSessionDate == nil {
            firstSessionDate = dateStr
            schedulePersist { await self.persistFirstSessionDate() }
        }

        distinctDaysUsed.insert(dateStr)
        schedulePersist { await self.persistDistinctDays() }

        let newSession = StoredSession(startedAt: now, durationInSeconds: 0)
        recentSessions.append(newSession)
        schedulePersist { await self.persistSessions() }
    }

    private func handleBackground() {
        let now = Date()
        backgroundDate = now

        guard let start = currentSessionStart else { return }
        currentSessionPausedAt = now

        let elapsed = Int(now.timeIntervalSince(start)) - currentSessionAccumulatedSeconds
        if var lastSession = recentSessions.last {
            lastSession.durationInSeconds += elapsed
            recentSessions[recentSessions.count - 1] = lastSession
            schedulePersist { await self.persistSessions() }
        }
        currentSessionAccumulatedSeconds += elapsed
    }

    private func handleForeground() async {
        let didRotate: Bool
        if let bgDate = backgroundDate, Date().timeIntervalSince(bgDate) > Self.backgroundThreshold {
            backgroundDate = nil
            if var lastSession = recentSessions.last, currentSessionAccumulatedSeconds > 0 {
                lastSession.durationInSeconds = currentSessionAccumulatedSeconds
                recentSessions[recentSessions.count - 1] = lastSession
                schedulePersist { await self.persistSessions() }
            }
            currentSession = UUID()
            recordSessionStart()
            didRotate = true
        } else {
            backgroundDate = nil
            currentSessionPausedAt = nil
            didRotate = false
        }

        if didRotate, sendSessionStartedEvent {
            await emitter?.send(EventInput(DefaultEvents.Session.started.rawValue, skipsReservedPrefixValidation: true))
        }
    }

    private func cleanOldSessions() {
        let cutoff = Date().addingTimeInterval(-90 * 24 * 3600)
        let kept = recentSessions.filter { $0.startedAt >= cutoff }
        let removed = recentSessions.count - kept.count
        if removed > 0 {
            deletedSessionsCount += removed
            recentSessions = kept
            schedulePersist {
                await self.persistSessions()
                await self.persistDeletedCount()
            }
        }
    }

    private func updateDistinctDays() {
        var days = Set<String>()
        for session in recentSessions {
            days.insert(dateString(from: session.startedAt))
        }
        distinctDaysUsed = days
        schedulePersist { await self.persistDistinctDays() }
    }

    private func dateString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func persistSessions() async {
        guard let data = try? JSONEncoder().encode(recentSessions) else { return }
        await storage?.set(data, forKey: "recentSessions")
    }

    private func persistDeletedCount() async {
        await storage?.set(deletedSessionsCount, forKey: "deletedSessionsCount")
    }

    private func persistFirstSessionDate() async {
        await storage?.set(firstSessionDate, forKey: "firstSessionDate")
    }

    private func persistDistinctDays() async {
        guard let data = try? JSONEncoder().encode(distinctDaysUsed) else { return }
        await storage?.set(data, forKey: "distinctDaysUsed")
    }
}
