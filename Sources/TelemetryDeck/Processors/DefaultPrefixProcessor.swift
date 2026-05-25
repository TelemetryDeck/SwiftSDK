import Foundation

/// Applies the configured event name prefix and parameter prefix to events that are not already prefixed.
public struct DefaultPrefixProcessor: EventProcessor {
    private let eventPrefix: String?
    private let parameterPrefix: String?

    /// Creates a default prefix processor with optional event and parameter prefixes.
    public init(eventPrefix: String? = nil, parameterPrefix: String? = nil) {
        self.eventPrefix = eventPrefix
        self.parameterPrefix = parameterPrefix
    }

    /// Prepends the configured event and parameter prefixes where applicable.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var input = input

        if let eventPrefix,
            !input.name.hasPrefix(eventPrefix),
            !input.name.hasPrefix("TelemetryDeck.")
        {
            input.name = eventPrefix + input.name
        }

        if let parameterPrefix {
            var prefixed = EventParameters()
            for (key, value) in input.parameters {
                if key.hasPrefix("TelemetryDeck.") {
                    prefixed[key] = value
                } else {
                    prefixed[parameterPrefix + key] = value
                }
            }
            input.parameters = prefixed
        }

        return try await next(input, context)
    }
}
