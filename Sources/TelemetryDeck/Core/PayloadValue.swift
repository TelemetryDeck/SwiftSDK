import Foundation

/// A typed payload value that encodes as a native JSON type.
public enum PayloadValue: Sendable, Codable, Equatable, Hashable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)

    /// Decodes from a single JSON value, preserving integer and double distinctions.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int64.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode PayloadValue")
        }
    }

    /// Encodes as a native JSON value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

extension PayloadValue: CustomStringConvertible {
    /// A human-readable representation of the underlying value.
    public var description: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        }
    }
}

extension PayloadValue: ExpressibleByStringLiteral {
    /// Creates a string payload value from a string literal.
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PayloadValue: ExpressibleByIntegerLiteral {
    /// Creates an integer payload value from an integer literal.
    public init(integerLiteral value: Int64) {
        self = .int(value)
    }
}

extension PayloadValue: ExpressibleByFloatLiteral {
    /// Creates a double payload value from a float literal.
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension PayloadValue: ExpressibleByBooleanLiteral {
    /// Creates a boolean payload value from a boolean literal.
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}
