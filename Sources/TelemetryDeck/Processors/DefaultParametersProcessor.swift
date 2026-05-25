import Foundation

/// Merges the configured default parameters into every event's input parameters so they pass through the full pipeline.
public struct DefaultParametersProcessor: EventProcessor {
    private let parameters: EventParameters

    /// Creates a default parameters processor with the given parameters.
    public init(parameters: EventParameters = [:]) {
        self.parameters = parameters
    }

    /// Prepends the configured default parameters to the event input, allowing subsequent processors and user-supplied parameters to override them.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var input = input
        var merged = parameters
        merged.merge(input.parameters)
        input.parameters = merged
        return try await next(input, context)
    }
}
