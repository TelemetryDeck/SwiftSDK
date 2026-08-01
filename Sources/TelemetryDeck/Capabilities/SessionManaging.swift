import Foundation

/// An event processor that also exposes session management capabilities.
public protocol SessionManaging: EventProcessor {
    func currentSessionID() async -> UUID
    func startNewSession() async -> UUID
}

/// Shared constants for session lifecycle behaviour.
enum SessionConstants {
    static let backgroundThreshold: TimeInterval = 5 * 60
}
