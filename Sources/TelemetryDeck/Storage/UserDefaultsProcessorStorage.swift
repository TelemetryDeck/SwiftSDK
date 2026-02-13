import Foundation

/// A `ProcessorStorage` implementation backed by a `UserDefaults` suite.
public actor UserDefaultsProcessorStorage: ProcessorStorage {
    private let defaults: UserDefaults

    /// Creates a storage backed by the `UserDefaults` suite with the given name.
    public init(suiteName: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// Returns the data stored for the given key, or `nil` if absent.
    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    /// Stores or removes data for the given key.
    public func set(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    /// Returns the string stored for the given key, or `nil` if absent.
    public func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    /// Stores or removes a string for the given key.
    public func set(_ value: String?, forKey key: String) { defaults.set(value, forKey: key) }
    /// Returns the integer stored for the given key, or `0` if absent.
    public func integer(forKey key: String) -> Int { defaults.integer(forKey: key) }
    /// Stores an integer for the given key.
    public func set(_ value: Int, forKey key: String) { defaults.set(value, forKey: key) }
    /// Returns the boolean stored for the given key, or `false` if absent.
    public func bool(forKey key: String) -> Bool { defaults.bool(forKey: key) }
    /// Stores a boolean for the given key.
    public func set(_ value: Bool, forKey key: String) { defaults.set(value, forKey: key) }
    /// Returns the string array stored for the given key, or `nil` if absent.
    public func stringArray(forKey key: String) -> [String]? { defaults.stringArray(forKey: key) }
}
