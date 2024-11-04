import Foundation

// Source: https://github.com/FlineDev/HandySwift/blob/main/Sources/HandySwift/Extensions/DictionaryExt.swift

extension Dictionary {
    /// Transforms the keys of the dictionary using the given closure, returning a new dictionary with the transformed keys.
    ///
    /// - Parameter transform: A closure that takes a key from the dictionary as its argument and returns a new key.
    /// - Returns: A dictionary with keys transformed by the `transform` closure and the same values as the original dictionary.
    /// - Throws: Rethrows any error thrown by the `transform` closure.
    ///
    /// - Warning: If the `transform` closure produces duplicate keys, the values of earlier keys will be overridden by the values of later keys in the resulting dictionary.
    ///
    /// - Example:
    /// ```
    /// let originalDict = ["one": 1, "two": 2, "three": 3]
    /// let transformedDict = originalDict.mapKeys { $0.uppercased() }
    /// // transformedDict will be ["ONE": 1, "TWO": 2, "THREE": 3]
    /// ```
    func mapKeys<K: Hashable>(_ transform: (Key) throws -> K) rethrows -> [K: Value] {
        var transformedDict: [K: Value] = [:]
        for (key, value) in self {
            transformedDict[try transform(key)] = value
        }
        return transformedDict
    }
}
