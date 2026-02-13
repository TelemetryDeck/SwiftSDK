import Foundation

/// An event processor that manages the current user identifier.
public protocol UserIdentifierManaging: EventProcessor {
    func currentUserIdentifier() async -> String?
    func setUserIdentifier(_ value: String?) async
}
