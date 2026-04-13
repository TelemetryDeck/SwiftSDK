import Foundation

/// A typed collection of event parameters keyed by string.
public struct EventParameters: Sendable, ExpressibleByDictionaryLiteral, Sequence {
    private var storage: [String: any ParameterValue]

    /// Creates an empty parameters collection.
    public init() {
        self.storage = [:]
    }

    /// Creates a parameters collection from a dictionary literal.
    public init(dictionaryLiteral elements: (String, any ParameterValue)...) {
        self.storage = Dictionary(uniqueKeysWithValues: elements)
    }

    /// Creates a parameters collection from a plain string dictionary.
    public init(_ dictionary: [String: String]) {
        self.storage = dictionary
    }

    /// Accesses a parameter value by string key.
    public subscript(key: String) -> (any ParameterValue)? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    /// Accesses a parameter value by raw-representable key.
    public subscript<K: RawRepresentable>(key: K) -> (any ParameterValue)? where K.RawValue == String {
        get { storage[key.rawValue] }
        set { storage[key.rawValue] = newValue }
    }

    /// Merges another `EventParameters` collection into this one, overwriting existing keys.
    public mutating func merge(_ other: EventParameters) {
        for (key, value) in other.storage {
            storage[key] = value
        }
    }

    /// Merges a plain string dictionary into this collection, overwriting existing keys.
    public mutating func merge(_ other: [String: String]) {
        for (key, value) in other {
            storage[key] = value
        }
    }

    /// All parameters converted to a plain `[String: String]` dictionary.
    public var stringDictionary: [String: String] {
        storage.mapValues { $0.parameterStringValue }
    }

    /// All parameters converted to a typed `[String: PayloadValue]` dictionary.
    public var payloadDictionary: [String: PayloadValue] {
        storage.mapValues { $0.payloadValue }
    }

    /// The number of parameters in the collection.
    public var count: Int { storage.count }
    /// Whether the collection contains no parameters.
    public var isEmpty: Bool { storage.isEmpty }
    /// The keys present in the collection.
    public var keys: Dictionary<String, any ParameterValue>.Keys { storage.keys }

    /// Returns an iterator over the key-value pairs.
    public func makeIterator() -> Dictionary<String, any ParameterValue>.Iterator {
        storage.makeIterator()
    }
}
