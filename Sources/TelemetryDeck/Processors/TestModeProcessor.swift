import Foundation

/// Determines whether events should be marked as test-mode, defaulting to `DEBUG` build configuration.
public struct TestModeProcessor: EventProcessor, TestModeProviding {
    private let override: Bool?

    /// Creates a test mode processor with an optional explicit override.
    public init(override: Bool? = nil) {
        self.override = override
    }

    /// Returns `true` when test mode is active, either via override or in DEBUG builds.
    public func isTestMode() async -> Bool {
        if let override { return override }
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    /// Sets the `isTestMode` flag on the context and passes through.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.isTestMode = await isTestMode()
        return try await next(input, context)
    }
}
