import Foundation

extension TelemetryDeck {
    /// How often heartbeat events are sent.
    public enum HeartbeatFrequency: Sendable {
        case minute
    }
}

extension TelemetryDeck.HeartbeatFrequency {
    var interval: TimeInterval {
        switch self {
        case .minute:
            60
        }
    }
}
