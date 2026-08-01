import Foundation

/// Persistent key-value storage used by event processors to save and restore state between launches.
public protocol ProcessorStorage: Sendable {
    func data(forKey key: String) async -> Data?
    func set(_ data: Data?, forKey key: String) async
    func string(forKey key: String) async -> String?
    func set(_ value: String?, forKey key: String) async
    func integer(forKey key: String) async -> Int
    func set(_ value: Int, forKey key: String) async
    func bool(forKey key: String) async -> Bool
    func set(_ value: Bool, forKey key: String) async
    /// Returns a string array for the given key; used internally for v2 data migration.
    func stringArray(forKey key: String) async -> [String]?
}

extension ProcessorStorage {
    /// Returns `nil` by default; overridden by `UserDefaultsProcessorStorage` to read plist arrays.
    public func stringArray(forKey key: String) async -> [String]? { nil }
}
