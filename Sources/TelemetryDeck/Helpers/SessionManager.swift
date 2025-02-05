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

    private var recentSessions: [StoredSession]

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
        let completedSessions = self.recentSessions.dropLast()
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

    private var currentSessionStartedAt: Date = .distantPast
    private var currentSessionDuration: TimeInterval = .zero

    private var sessionDurationUpdater: Timer?
    private var sessionDurationLastUpdatedAt: Date?

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.sessionmanager.persistence")

    private init() {
        if
            let existingSessionData = TelemetryDeck.customDefaults?.data(forKey: Self.recentSessionsKey),
            let existingSessions = try? Self.decoder.decode([StoredSession].self, from: existingSessionData)
        {
            // upon app start, clean up any sessions older than 90 days to keep dict small
            let cutoffDate = Date().addingTimeInterval(-(90 * 24 * 60 * 60))
            self.recentSessions = existingSessions.filter { $0.startedAt > cutoffDate }

            // Update deleted sessions count
            self.deletedSessionsCount += existingSessions.count - self.recentSessions.count
        } else {
            self.recentSessions = []
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

    @objc
    private func updateSessionDuration() {
        if let sessionDurationLastUpdatedAt {
            self.currentSessionDuration += Date().timeIntervalSince(sessionDurationLastUpdatedAt)
        }

        self.sessionDurationLastUpdatedAt = Date()
        self.persistCurrentSessionIfNeeded()
    }

    private func persistCurrentSessionIfNeeded() {
        // Ignore sessions under 1 second
        guard self.currentSessionDuration >= 1.0 else { return }

        // Add or update the current session
        if let existingSessionIndex = self.recentSessions.lastIndex(where: { $0.startedAt == self.currentSessionStartedAt }) {
            self.recentSessions[existingSessionIndex].durationInSeconds = Int(self.currentSessionDuration)
        } else {
            let newSession = StoredSession(startedAt: self.currentSessionStartedAt, durationInSeconds: Int(self.currentSessionDuration))
            self.recentSessions.append(newSession)
        }

        // Save changes to UserDefaults without blocking Main thread
        self.persistenceQueue.async {
            if let updatedSessionData = try? Self.encoder.encode(self.recentSessions) {
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
