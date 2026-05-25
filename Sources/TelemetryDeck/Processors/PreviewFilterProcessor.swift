import Foundation

/// Filters out events when the app is running inside an Xcode SwiftUI preview.
public struct PreviewFilterProcessor: EventProcessor {
    private let isPreviewMode: Bool

    /// Creates a processor that detects preview mode from the process environment.
    public init() {
        self.isPreviewMode = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Throws `ProcessorError.eventFiltered` when running inside an Xcode preview.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        guard !isPreviewMode else {
            throw ProcessorError.eventFiltered
        }
        return try await next(input, context)
    }
}
