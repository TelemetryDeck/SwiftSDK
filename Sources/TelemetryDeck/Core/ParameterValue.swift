import Foundation

/// A type that can be serialised as a parameter value in an event payload.
public protocol ParameterValue: Sendable {
    /// The typed payload representation of this value.
    var payloadValue: PayloadValue { get }
}

extension String: ParameterValue {
    /// Returns a string payload value.
    public var payloadValue: PayloadValue { .string(self) }
}

extension Bool: ParameterValue {
    /// Returns a boolean payload value.
    public var payloadValue: PayloadValue { .bool(self) }
}

extension Int: ParameterValue {
    /// Returns an integer payload value.
    public var payloadValue: PayloadValue { .int(Int64(self)) }
}

extension Int64: ParameterValue {
    /// Returns an integer payload value.
    public var payloadValue: PayloadValue { .int(self) }
}

extension Int32: ParameterValue {
    /// Returns an integer payload value.
    public var payloadValue: PayloadValue { .int(Int64(self)) }
}

extension UInt: ParameterValue {
    /// Returns an integer payload value.
    public var payloadValue: PayloadValue { .int(Int64(self)) }
}

extension UInt64: ParameterValue {
    /// Returns an integer payload value, clamped to `Int64` range.
    public var payloadValue: PayloadValue { .int(Int64(clamping: self)) }
}

extension Double: ParameterValue {
    /// Returns a double payload value.
    public var payloadValue: PayloadValue { .double(self) }
}

extension Float: ParameterValue {
    /// Returns a double payload value.
    public var payloadValue: PayloadValue { .double(Double(self)) }
}

extension UUID: ParameterValue {
    /// Returns a string payload value containing the UUID string.
    public var payloadValue: PayloadValue { .string(uuidString) }
}

extension Date: ParameterValue {
    /// Returns a string payload value containing the ISO 8601 date.
    public var payloadValue: PayloadValue { .string(ISO8601DateFormatter().string(from: self)) }
}

extension PayloadValue: ParameterValue {
    /// Returns itself as the payload value.
    public var payloadValue: PayloadValue { self }
}
