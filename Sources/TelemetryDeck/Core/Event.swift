import Foundation

/// A finalized event ready for transmission to the TelemetryDeck ingestion API.
public struct Event: Sendable, Codable {
    /// The TelemetryDeck app identifier.
    public let appID: String
    /// The event name.
    public let type: String
    /// The hashed user identifier.
    public let clientUser: String
    /// The session identifier associated with this event.
    public let sessionID: String?
    /// The timestamp at which the event was recorded on the client.
    public let receivedAt: Date
    /// The enriched parameter payload.
    public let payload: [String: PayloadValue]
    /// An optional numeric value associated with the event.
    public let floatValue: Double?
    /// Indicates whether this event is a test-mode event ("true" or "false").
    public let isTestMode: String

    /// Creates an event with the given fields, converting the boolean test mode flag to a string.
    public init(
        appID: String,
        type: String,
        clientUser: String,
        sessionID: String?,
        receivedAt: Date,
        payload: [String: PayloadValue],
        floatValue: Double?,
        isTestMode: Bool
    ) {
        self.appID = appID
        self.type = type
        self.clientUser = clientUser
        self.sessionID = sessionID
        self.receivedAt = receivedAt
        self.payload = payload
        self.floatValue = floatValue
        self.isTestMode = isTestMode ? "true" : "false"
    }
}
