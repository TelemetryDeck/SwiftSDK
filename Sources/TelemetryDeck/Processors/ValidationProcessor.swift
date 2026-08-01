import Foundation

/// Warns when event names or parameter keys use reserved TelemetryDeck identifiers.
public actor ValidationProcessor: EventProcessor {
    private static let reservedKeysLowercased: Set<String> = Set(
        [
            "type", "clientUser", "appID", "sessionID", "floatValue",
            "newSessionBegan", "platform", "systemVersion", "majorSystemVersion", "majorMinorSystemVersion",
            "appVersion", "buildNumber", "isSimulator", "isDebug", "isTestFlight", "isAppStore",
            "modelName", "architecture", "operatingSystem", "targetEnvironment",
            "locale", "region", "appLanguage", "preferredLanguage", "telemetryClientVersion",
            "extensionIdentifier",
        ].map { $0.lowercased() }
    )

    private var logger: any Logging = DefaultLogger()

    /// Creates a validation processor.
    public init() {}

    /// Captures the logger for use during event processing.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        self.logger = logger
    }

    /// Logs warnings for reserved event names or parameter keys, then passes through.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        let nameLowercased = input.name.lowercased()
        if !input.skipsReservedPrefixValidation && nameLowercased.hasPrefix("telemetrydeck.") {
            logger.log(.error, "Event name '\(input.name)' uses reserved prefix 'TelemetryDeck.'")
        } else if Self.reservedKeysLowercased.contains(nameLowercased) {
            logger.log(.error, "Event name '\(input.name)' is a reserved name")
        }

        for key in input.parameters.keys {
            let keyLowercased = key.lowercased()
            if !input.skipsReservedPrefixValidation && keyLowercased.hasPrefix("telemetrydeck.") {
                logger.log(.error, "Parameter key '\(key)' uses reserved prefix 'TelemetryDeck.'")
            } else if Self.reservedKeysLowercased.contains(keyLowercased) {
                logger.log(.error, "Parameter key '\(key)' is a reserved name")
            }
        }

        return try await next(input, context)
    }
}
