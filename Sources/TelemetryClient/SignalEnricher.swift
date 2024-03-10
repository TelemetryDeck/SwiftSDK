import Foundation

public protocol SignalEnricher {
    func enrich(
        signalType: TelemetrySignalType,
        for clientUser: String?,
        floatValue: Double?
    ) -> [String: String]
}

extension Dictionary where Key == String, Value == String {
    func applying(_ rhs: [String: String]) -> [String: String] {
        merging(rhs) { _, rhs in
            rhs
        }
    }
}
