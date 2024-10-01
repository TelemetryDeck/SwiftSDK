import Foundation

public protocol SignalEnricher: Sendable {
    func enrich(
        signalType: String,
        for clientUser: String?,
        floatValue: Double?
    ) -> [String: String]
}

extension Dictionary where Key == String, Value == String {
    func applying(_ other: [String: String]) -> [String: String] {
        merging(other) { _, other in
            other
        }
    }
}
