#if canImport(WatchKit)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// TODO: test logic of this class in a real-world app to find edge cases (unit tests feasible?)
// TODO: add automatic sending of session lengths as default parameters
// TODO: persist save dinstinct days used count separately
// TODO: persist first install date separately

final class SessionManager: @unchecked Sendable {
    private struct StoredSession: Codable {
        let startedAt: Date
        let durationInSeconds: Int
    }

    static let shared = SessionManager()
    private static let sessionsKey = "sessions"

    private var sessionsByID: [UUID: StoredSession]

    private var currentSessionID: UUID = UUID()
    private var currentSessionStartetAt: Date = .distantPast
    private var currentSessionDuration: TimeInterval = .zero

    private var sessionDurationUpdater: Timer?
    private var sessionDurationLastUpdatedAt: Date?

    private let persistenceQueue = DispatchQueue(label: "com.telemetrydeck.sessionmanager.persistence")

    private init() {
        if
            let existingSessionData = TelemetryDeck.customDefaults?.data(forKey: Self.sessionsKey),
            let existingSessions = try? JSONDecoder().decode([UUID: StoredSession].self, from: existingSessionData)
        {
            // upon app start, clean up any sessions older than 90 days to keep dict small
            let cutoffDate = Date().addingTimeInterval(-(90 * 24 * 60 * 60))
            self.sessionsByID = existingSessions.filter { $0.value.startedAt > cutoffDate }
        } else {
            self.sessionsByID = [:]
        }

        self.setupAppLifecycleObservers()
    }

    func startSessionTimer() {
        // stop automatic duration counting of previous session
        self.stopSessionTimer()

        // TODO: when sessionsByID is empty here, then send "`newInstallDetected`" with `firstSessionDate`

        // start a new session
        self.currentSessionID = UUID()
        self.currentSessionStartetAt = Date()
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
        self.sessionsByID[self.currentSessionID] = StoredSession(
            startedAt: self.currentSessionStartetAt,
            durationInSeconds: Int(self.currentSessionDuration)
        )

        // Save changes to UserDefaults without blocking Main thread
        self.persistenceQueue.async {
            guard let updatedSessionData = try? JSONEncoder().encode(self.sessionsByID) else { return }
            TelemetryDeck.customDefaults?.set(updatedSessionData, forKey: Self.sessionsKey)
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
