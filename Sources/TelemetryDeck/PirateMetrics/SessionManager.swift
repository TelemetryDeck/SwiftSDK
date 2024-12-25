import Foundation

@MainActor
final class SessionManager {
    static let shared = SessionManager()
    private init() {}

    // TODO: make sure that all session start dates and their duration are persisted (use a Codable?)
    // TODO: implement auto-detection of new install and send `newInstallDetected` with `firstSessionDate`
}
