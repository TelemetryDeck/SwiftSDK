import Foundation

/// Raw event data provided by the caller before processing through the pipeline.
public struct EventInput: Sendable {
    /// The event name.
    public var name: String
    /// Caller-supplied parameters to attach to the event.
    public var parameters: EventParameters
    /// An optional numeric value associated with the event.
    public var floatValue: Double?
    /// An optional user identifier that overrides the default for this event only.
    public var customUserID: String?
    /// The time at which the event was created.
    public let timestamp: Date
    /// When true, the validation processor skips reserved-prefix checks for this event.
    public var skipsReservedPrefixValidation: Bool

    /// Creates an event input with the given name, optional parameters, float value, and user override.
    public init(
        _ name: String,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil,
        skipsReservedPrefixValidation: Bool = false
    ) {
        self.name = name
        self.parameters = parameters
        self.floatValue = floatValue
        self.customUserID = customUserID
        self.timestamp = Date()
        self.skipsReservedPrefixValidation = skipsReservedPrefixValidation
    }
}
