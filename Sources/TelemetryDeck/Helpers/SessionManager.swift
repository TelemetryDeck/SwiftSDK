#if canImport(WatchKit)
    import WatchKit
#elseif canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@available(watchOS 7, *)
final class SessionManager: @unchecked Sendable {
    private struct StoredSession: Codable {
        let startedAt: Date
        var durationInSeconds: Int

        // Let's save some extra space in UserDefaults by using shorter keys.
        private enum CodingKeys: String, CodingKey {
            case startedAt = "st"
            case durationInSeconds = "dn"
        }
    }

    static let shared = SessionManager()

    private static let recentSessionsKey = "recentSessions"
    private static let deletedSessionsCountKey = "deletedSessionsCount"

    private static let firstSessionDateKey = "firstSessionDate"
    private static let distinctDaysUsedKey = "distinctDaysUsed"

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // removes sub-second level precision from the start date as we don't need it
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let timestamp = Int(date.timeIntervalSince1970)
            var container = encoder.singleValueContainer()
            try container.encode(timestamp)
        }
        return encoder
    }()

    /// Guards ``unsafeRecentSessions``.
    ///
    /// Only ever held around the array access itself, never while encoding or writing to
    /// `UserDefaults`, so a reader can never end up waiting behind that I/O.
    private let sessionsLock = NSLock()

    /// Only ever touched while holding ``sessionsLock``. Read it through ``recentSessions``.
    private var unsafeRecentSessions: [StoredSession]

    /// A snapshot of the recorded sessions, safe to read from any thread.
    private var recentSessions: [StoredSession] {
        self.sessionsLock.lock()
        defer { self.sessionsLock.unlock() }
        return self.unsafeRecentSessions
    }

    private var deletedSessionsCount: Int {
        get { TelemetryDeck.customDefaults?.integer(forKey: Self.deletedSessionsCountKey) ?? 0 }
        set {
            self.persistenceQueue.async {
                TelemetryDeck.customDefaults?.set(newValue, forKey: Self.deletedSessionsCountKey)
            }
        }
    }

    var totalSessionsCount: Int {
        self.recentSessions.count + self.deletedSessionsCount
    }

    var averageSessionSeconds: Int {
        // Snapshot once: reading `recentSessions` repeatedly would take the lock each time and
        // could observe a different array on every read.
        let recentSessions = self.recentSessions

        guard recentSessions.count > 1 else {
            return recentSessions.first?.durationInSeconds ?? -1
        }

        let completedSessions = recentSessions.dropLast()
        let totalCompletedSessionSeconds = completedSessions.map(\.durationInSeconds).reduce(into: 0) { $0 += $1 }
        return totalCompletedSessionSeconds / completedSessions.count
    }

    var previousSessionSeconds: Int? {
        self.recentSessions.dropLast().last?.durationInSeconds
    }

    var firstSessionDate: String {
        get {
            TelemetryDeck.customDefaults?.string(forKey: Self.firstSessionDateKey)
                ?? ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        }
        set {
            self.persistenceQueue.async {
                TelemetryDeck.customDefaults?.set(newValue, forKey: Self.firstSessionDateKey)
            }
        }
    }

    var distinctDaysUsed: [String] {
        get { TelemetryDeck.customDefaults?.stringArray(forKey: Self.distinctDaysUsedKey) ?? [] }
        set {
            self.persistenceQueue.async {
                TelemetryDeck.customDefaults?.set(newValue, forKey: Self.distinctDaysUsedKey)
            }
        }
    }

    var distinctDaysUsedLastMonthCount: Int {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        // Get date 30 days ago
        let thirtyDaysAgoDate = Date().addingTimeInterval(-(30 * 24 * 60 * 60))
        let thirtyDaysAgoFormatted = dateFormatter.string(from: thirtyDaysAgoDate)

        return self.distinctDaysUsed.countISODatesOnOrAfter(cutoffISODate: thirtyDaysAgoFormatted)
    }

    private var currentSessionStartedAt: Date = .distantPast
    private var currentSessionDuration: TimeInterval = .zero

    private var sessionDurationUpdater: Timer?
    private var sessionDurationLastUpdatedAt: Date?

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.sessionmanager.persistence")

    // Not `private` so tests can exercise an isolated instance instead of the shared singleton.
    init() {
        if let existingSessionData = TelemetryDeck.customDefaults?.data(forKey: Self.recentSessionsKey),
            let existingSessions = try? Self.decoder.decode([StoredSession].self, from: existingSessionData)
        {
            // upon app start, clean up any sessions older than 90 days to keep dict small
            let cutoffDate = Date().addingTimeInterval(-(90 * 24 * 60 * 60))
            self.unsafeRecentSessions = existingSessions.filter { $0.startedAt > cutoffDate }

            // Update deleted sessions count
            self.deletedSessionsCount += existingSessions.count - self.unsafeRecentSessions.count
        } else {
            self.unsafeRecentSessions = []
        }

        self.updateDistinctDaysUsed()
        self.setupAppLifecycleObservers()
    }

    func startNewSession() {
        // stop automatic duration counting of previous session
        self.stopSessionTimer()

        // if the recent sessions are empty, this must be the first start after installing the app
        if self.recentSessions.isEmpty {
            // this ensures we only use the date, not the time –> e.g. "2025-01-31"
            let todayFormatted = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])

            self.firstSessionDate = todayFormatted

            TelemetryDeck.internalSignal(
                "TelemetryDeck.Acquisition.newInstallDetected",
                parameters: ["TelemetryDeck.Acquisition.firstSessionDate": todayFormatted]
            )
        }

        // start a new session
        self.currentSessionStartedAt = Date()
        self.currentSessionDuration = .zero

        // start automatic duration counting of new session
        self.updateSessionDuration()
        self.sessionDurationUpdater = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateSessionDuration),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopSessionTimer() {
        self.sessionDurationUpdater?.invalidate()
        self.sessionDurationUpdater = nil
        self.sessionDurationLastUpdatedAt = nil
    }

    // Not `private` so tests can drive a tick directly instead of waiting on the run-loop timer.
    @objc
    func updateSessionDuration() {
        if let sessionDurationLastUpdatedAt {
            self.currentSessionDuration += Date().timeIntervalSince(sessionDurationLastUpdatedAt)
        }

        self.sessionDurationLastUpdatedAt = Date()
        self.persistCurrentSessionIfNeeded()
    }

    private func persistCurrentSessionIfNeeded() {
        // Ignore sessions under 1 second
        guard self.currentSessionDuration >= 1.0 else { return }

        let startedAt = self.currentSessionStartedAt
        let durationInSeconds = Int(self.currentSessionDuration)

        // Update *and* save on the queue, without blocking the Main thread. Doing the mutation here
        // rather than at the call site is what keeps this once-per-second bookkeeping off the run
        // loop: previously the caller mutated the array while a queued encode still referenced it,
        // so every tick both raced that encode and had to copy the whole array before it could
        // mutate — which ThreadSanitizer flags, and which can crash or stall in `Array.subscript`.
        self.persistenceQueue.async {
            self.sessionsLock.lock()

            // Add or update the current session
            if let existingSessionIndex = self.unsafeRecentSessions.lastIndex(where: { $0.startedAt == startedAt }) {
                self.unsafeRecentSessions[existingSessionIndex].durationInSeconds = durationInSeconds
            } else {
                let newSession = StoredSession(startedAt: startedAt, durationInSeconds: durationInSeconds)
                self.unsafeRecentSessions.append(newSession)
            }

            let updatedSessions = self.unsafeRecentSessions
            self.sessionsLock.unlock()

            // Encode outside the lock: the queue is serial, so this snapshot is released before the
            // next tick runs and that tick can mutate the array in place.
            if let updatedSessionData = try? Self.encoder.encode(updatedSessions) {
                TelemetryDeck.customDefaults?.set(updatedSessionData, forKey: Self.recentSessionsKey)
            }
        }
    }

    @objc
    private func handleDidEnterBackgroundNotification() {
        self.updateSessionDuration()
        self.stopSessionTimer()
    }

    @objc
    private func handleWillEnterForegroundNotification() {
        self.updateSessionDuration()
        self.sessionDurationUpdater = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateSessionDuration),
            userInfo: nil,
            repeats: true
        )
    }

    private func updateDistinctDaysUsed() {
        let todayFormatted = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])

        var distinctDays = self.distinctDaysUsed
        if distinctDays.last != todayFormatted {
            distinctDays.append(todayFormatted)
            self.distinctDaysUsed = distinctDays
        }
    }

    private func setupAppLifecycleObservers() {
        #if canImport(WatchKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDidEnterBackgroundNotification),
                name: WKApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWillEnterForegroundNotification),
                name: WKApplication.willEnterForegroundNotification,
                object: nil
            )
        #elseif canImport(UIKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDidEnterBackgroundNotification),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWillEnterForegroundNotification),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        #elseif canImport(AppKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDidEnterBackgroundNotification),
                name: NSApplication.didResignActiveNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWillEnterForegroundNotification),
                name: NSApplication.willBecomeActiveNotification,
                object: nil
            )
        #endif
    }
}

extension [String] {
    /// Counts ISO-formatted date strings (YYYY-MM-DD) that are on or after the given date.
    /// Uses string comparison since ISO dates sort alphabetically like dates chronologically.
    ///
    /// - Parameter cutoffISODate: The ISO date string to compare against
    /// - Returns: Count of dates on or after the cutoff
    func countISODatesOnOrAfter(cutoffISODate: String) -> Int {
        // Simply filter strings that are >= the cutoff date string
        // (works because: String compares alphabetically & ISO date format sorts dates alphabetically)
        self.filter { $0 >= cutoffISODate }.count
    }
}
