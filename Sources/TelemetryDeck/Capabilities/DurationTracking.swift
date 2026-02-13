import Foundation

/// The result of a completed duration measurement.
public struct DurationResult: Sendable {
    /// The elapsed time in seconds.
    public let durationInSeconds: TimeInterval
    /// The parameters that were recorded when the duration measurement started.
    public let startParameters: EventParameters
}

/// Tracks elapsed time for named events, optionally excluding background time.
public protocol DurationTracking: Sendable {
    func startDuration(
        _ eventName: String,
        parameters: EventParameters,
        includeBackgroundTime: Bool
    ) async

    func stopDuration(_ eventName: String) async -> DurationResult?

    func cancelDuration(_ eventName: String) async
}
