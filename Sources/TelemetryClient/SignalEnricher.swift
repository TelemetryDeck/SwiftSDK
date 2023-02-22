import Foundation

public protocol SignalEnricher {
    func enrich(
        signalType: String,
        for clientUser: String?,
        floatValue: Double?,
        with additionalPayload: [String: String]
    ) -> [String: String]
}

extension Dictionary where Key == String, Value == String {
    func applying(_ rhs: [String: String]) -> [String: String] {
        merging(rhs) { _, rhs in
            rhs
        }
    }
    
    func toMultiValueDimension() -> [String] {
        map { key, value in
            key.replacingOccurrences(of: ":", with: "_") + ":" + value
        }
    }
}
