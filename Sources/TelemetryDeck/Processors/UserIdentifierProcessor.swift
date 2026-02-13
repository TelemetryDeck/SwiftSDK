import Foundation

/// Resolves and attaches the effective user identifier to each event context.
public actor UserIdentifierProcessor: EventProcessor, UserIdentifierManaging {
    private let defaultUser: String?
    private var explicitUserID: String?
    private var cachedDefaultID: String?

    /// Creates a user identifier processor with an optional default user identifier.
    public init(defaultUser: String? = nil) {
        self.defaultUser = defaultUser
    }

    /// Resolves and caches the default user identifier from persistent storage.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        if let defaultUser {
            cachedDefaultID = defaultUser
        } else {
            cachedDefaultID = await UserIdentifier.resolveDefaultUserIdentifier(storage: storage)
        }
    }

    /// Returns the explicitly set identifier, falling back to the cached default.
    public func currentUserIdentifier() async -> String? {
        explicitUserID ?? cachedDefaultID
    }

    /// Sets an explicit user identifier that overrides the default for all subsequent events.
    public func setUserIdentifier(_ value: String?) async {
        explicitUserID = value
    }

    /// Resolves the effective user identifier and attaches it to the event context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        if let customID = input.customUserID {
            context.userIdentifier = customID
        } else if let explicitID = explicitUserID {
            context.userIdentifier = explicitID
        } else {
            context.userIdentifier = cachedDefaultID ?? "unknown user"
        }
        return try await next(input, context)
    }
}
