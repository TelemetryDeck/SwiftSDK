import Foundation

/// A test transmitter that records all transmitted events without sending them to the network.
public actor SpyEventTransmitter: EventTransmitting {
    /// All events that have been passed to `transmit(_:)`.
    public private(set) var transmittedEvents: [Event] = []

    /// Creates an empty spy transmitter.
    public init() {}

    /// Appends the events to the recorded list and reports success.
    public func transmit(_ events: [Event]) async -> [Event] {
        transmittedEvents.append(contentsOf: events)
        return []
    }

    /// No-op; no batched transmission is pending.
    public func flush() async {}
    /// No-op; no timer to start.
    public func start() async {}
    /// No-op; no timer to stop.
    public func stop() async {}
}
