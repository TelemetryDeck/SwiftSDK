import Foundation

/// Mutable context passed through the processor pipeline, accumulating enrichment data for an event.
public struct EventContext: Sendable {
    /// The session identifier to attach to the event.
    public var sessionID: UUID?
    /// The resolved user identifier for the event.
    public var userIdentifier: String?
    /// Whether the event should be marked as test-mode.
    public var isTestMode: Bool?

    /// Accumulated metadata parameters added by processors.
    public private(set) var metadata: EventParameters

    /// Creates an empty context.
    public init() {
        self.metadata = [:]
    }

    /// Adds a single parameter to the metadata using a string key.
    public mutating func addParameter(_ key: String, value: any ParameterValue) {
        metadata[key] = value
    }

    /// Adds a single parameter to the metadata using a raw-representable key.
    public mutating func addParameter<K: RawRepresentable>(_ key: K, value: any ParameterValue) where K.RawValue == String {
        metadata[key.rawValue] = value
    }

    /// Removes a parameter from the metadata by key.
    public mutating func removeParameter(_ key: String) {
        metadata[key] = nil
    }

    /// Merges the given `EventParameters` into the metadata, overwriting existing keys.
    public mutating func addParameters(_ params: EventParameters) {
        metadata.merge(params)
    }

    /// Merges the given string dictionary into the metadata, overwriting existing keys.
    public mutating func addParameters(_ params: [String: String]) {
        metadata.merge(params)
    }
}
