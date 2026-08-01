import Foundation

/// Sends batches of events to the TelemetryDeck ingestion API, returning any that failed.
public protocol EventTransmitting: Sendable {
    func transmit(_ events: [Event]) async -> [Event]
    func flush() async
    func start() async
    func stop() async
}
