import Foundation

/// A `ProcessorStorage` implementation backed by an in-memory dictionary.
public actor InMemoryProcessorStorage: ProcessorStorage {
    private var store: [String: Any] = [:]

    /// Creates an empty in-memory storage instance.
    public init() {}

    /// Returns the data stored for the given key, or `nil` if absent.
    public func data(forKey key: String) -> Data? {
        store[key] as? Data
    }

    /// Stores or removes data for the given key.
    public func set(_ data: Data?, forKey key: String) {
        store[key] = data
    }

    /// Returns the string stored for the given key, or `nil` if absent.
    public func string(forKey key: String) -> String? {
        store[key] as? String
    }

    /// Stores or removes a string for the given key.
    public func set(_ value: String?, forKey key: String) {
        store[key] = value
    }

    /// Returns the integer stored for the given key, or `0` if absent.
    public func integer(forKey key: String) -> Int {
        store[key] as? Int ?? 0
    }

    /// Stores an integer for the given key.
    public func set(_ value: Int, forKey key: String) {
        store[key] = value
    }

    /// Returns the boolean stored for the given key, or `false` if absent.
    public func bool(forKey key: String) -> Bool {
        store[key] as? Bool ?? false
    }

    /// Stores a boolean for the given key.
    public func set(_ value: Bool, forKey key: String) {
        store[key] = value
    }

    /// Returns the string array stored for the given key, or `nil` if absent.
    public func stringArray(forKey key: String) -> [String]? {
        store[key] as? [String]
    }

    func setStringArray(_ value: [String], forKey key: String) {
        store[key] = value
    }
}
