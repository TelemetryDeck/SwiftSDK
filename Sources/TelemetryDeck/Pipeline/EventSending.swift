import Foundation

/// Allows processors to submit events for pipeline processing and transmission.
public protocol EventSending: Sendable {
    func send(_ input: EventInput) async
}
