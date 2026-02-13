import Foundation

/// A type that can be serialised as a string parameter value in an event payload.
public protocol ParameterValue: Sendable {
    /// The string representation of this value used in the event payload.
    var parameterStringValue: String { get }
}

extension String: ParameterValue {
    /// Returns the string itself.
    public var parameterStringValue: String { self }
}

extension Bool: ParameterValue {
    /// Returns `"true"` or `"false"`.
    public var parameterStringValue: String { self ? "true" : "false" }
}

extension Int: ParameterValue {
    /// Returns the decimal string representation.
    public var parameterStringValue: String { String(self) }
}

extension Int64: ParameterValue {
    /// Returns the decimal string representation.
    public var parameterStringValue: String { String(self) }
}

extension Int32: ParameterValue {
    /// Returns the decimal string representation.
    public var parameterStringValue: String { String(self) }
}

extension UInt: ParameterValue {
    /// Returns the decimal string representation.
    public var parameterStringValue: String { String(self) }
}

extension UInt64: ParameterValue {
    /// Returns the decimal string representation.
    public var parameterStringValue: String { String(self) }
}

extension Double: ParameterValue {
    /// Returns the default string representation.
    public var parameterStringValue: String { String(self) }
}

extension Float: ParameterValue {
    /// Returns the default string representation.
    public var parameterStringValue: String { String(self) }
}

extension UUID: ParameterValue {
    /// Returns the uppercase UUID string.
    public var parameterStringValue: String { uuidString }
}

extension Date: ParameterValue {
    /// Returns an ISO 8601 formatted date string.
    public var parameterStringValue: String {
        ISO8601DateFormatter().string(from: self)
    }
}
