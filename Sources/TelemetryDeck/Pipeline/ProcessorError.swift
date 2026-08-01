import Foundation

/// Errors that an event processor can throw to indicate filtering or processing failure.
public enum ProcessorError: Error, Sendable {
    case eventFiltered
    case processingFailed(underlying: any Error)
}
