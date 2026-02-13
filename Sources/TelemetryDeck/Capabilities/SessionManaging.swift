import Foundation

/// An event processor that also exposes session management capabilities.
public protocol SessionManaging: EventProcessor {
    func currentSessionID() async -> UUID
    func startNewSession() async -> UUID
}
