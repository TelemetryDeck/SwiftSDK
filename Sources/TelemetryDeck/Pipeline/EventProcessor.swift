import Foundation

/// A middleware component in the event processing pipeline that can enrich, filter, or transform events.
public protocol EventProcessor: Sendable {
    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event

    /// Called once when the SDK starts; allows the processor to load persisted state.
    func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async
    /// Called when the SDK shuts down; allows the processor to release resources.
    func stop() async
}

extension EventProcessor {
    /// Default no-op implementation.
    public func start(storage: any ProcessorStorage, logger: any Logging, emitter: any EventSending) async {}
    /// Default no-op implementation.
    public func stop() async {}
}
