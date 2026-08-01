import Foundation

/// An event processor that can report whether the SDK is currently operating in test mode.
public protocol TestModeProviding: EventProcessor {
    func isTestMode() async -> Bool
}
