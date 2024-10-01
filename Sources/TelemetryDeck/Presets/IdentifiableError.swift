import Foundation

/// A protocol that represents an error with an identifiable ID.
public protocol IdentifiableError: Error {
    /// A unique identifier for the error.
    var id: String { get }
}
