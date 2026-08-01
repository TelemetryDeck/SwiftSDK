import Foundation

/// Resolves and attaches the effective user identifier to each event context.
public actor UserIdentifierProcessor: EventProcessor, UserIdentifierManaging {
    private let configuredDefaultUser: String?
    private var explicitUserID: String?
    private var resolvedDefaultID: String?
    private var resolutionTask: Task<String?, Never>?
    private var storage: (any ProcessorStorage)?
    private let resolve: @Sendable (any ProcessorStorage) async -> String?

    /// Creates a user identifier processor with an optional default user identifier.
    public init(defaultUser: String? = nil) {
        self.init(defaultUser: defaultUser, resolve: UserIdentifier.resolveDefaultUserIdentifier)
    }

    init(defaultUser: String?, resolve: @escaping @Sendable (any ProcessorStorage) async -> String?) {
        self.configuredDefaultUser = defaultUser
        self.resolve = resolve
    }

    /// Captures the storage reference for lazy identifier resolution.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {
        self.storage = storage
        if let configuredDefaultUser {
            resolvedDefaultID = configuredDefaultUser
        }
    }

    /// Cancels any in-flight default identifier resolution and releases its reference.
    public func stop() async {
        resolutionTask?.cancel()
        resolutionTask = nil
    }

    /// Returns the explicitly set identifier, falling back to the resolved default.
    public func currentUserIdentifier() async -> String? {
        if let explicitUserID { return explicitUserID }
        return await resolvedDefaultIdentifier() ?? UserIdentifier.fallbackIdentifier
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
            context.userIdentifier = await resolvedDefaultIdentifier() ?? UserIdentifier.fallbackIdentifier
        }
        return try await next(input, context)
    }

    private func resolvedDefaultIdentifier() async -> String? {
        if let resolvedDefaultID { return resolvedDefaultID }
        if let resolutionTask { return await resolutionTask.value }
        guard let storage else { return nil }
        let task = Task { await resolve(storage) }
        resolutionTask = task
        let result = await task.value
        resolutionTask = nil
        if let result { resolvedDefaultID = result }
        return result
    }
}
