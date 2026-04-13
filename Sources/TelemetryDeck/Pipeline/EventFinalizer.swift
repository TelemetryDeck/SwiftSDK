import Foundation

/// Converts a processed `EventInput` and its accumulated `EventContext` into a transmittable `Event`.
public struct EventFinalizer: Sendable {
    private let configuration: TelemetryDeck.Config

    /// Creates a finalizer using the given configuration.
    public init(configuration: TelemetryDeck.Config) {
        self.configuration = configuration
    }

    /// Merges context metadata with event parameters and returns a fully populated `Event`.
    public func finalize(_ input: EventInput, context: EventContext) -> Event {
        var merged = context.metadata
        merged.merge(input.parameters)

        return Event(
            appID: configuration.appID,
            type: input.name,
            clientUser: CryptoHashing.sha256(
                string: context.userIdentifier ?? "unknown user",
                salt: configuration.salt
            ),
            sessionID: context.sessionID?.uuidString,
            receivedAt: input.timestamp,
            payload: merged.payloadDictionary,
            floatValue: input.floatValue,
            isTestMode: context.isTestMode ?? false
        )
    }
}
