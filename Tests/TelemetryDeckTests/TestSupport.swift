import Foundation

@testable import TelemetryDeck

actor InMemoryProcessorStorage: ProcessorStorage {
    private var storage: [String: Any] = [:]

    func data(forKey key: String) async -> Data? {
        storage[key] as? Data
    }

    func set(_ value: Data?, forKey key: String) async {
        storage[key] = value
    }

    func string(forKey key: String) async -> String? {
        storage[key] as? String
    }

    func set(_ value: String?, forKey key: String) async {
        storage[key] = value
    }

    func integer(forKey key: String) async -> Int {
        storage[key] as? Int ?? 0
    }

    func set(_ value: Int, forKey key: String) async {
        storage[key] = value
    }

    func bool(forKey key: String) async -> Bool {
        storage[key] as? Bool ?? false
    }

    func set(_ value: Bool, forKey key: String) async {
        storage[key] = value
    }

    func stringArray(forKey key: String) async -> [String]? {
        storage[key] as? [String]
    }

    func setStringArray(_ value: [String], forKey key: String) async {
        storage[key] = value
    }
}

struct NoOpLogger: Logging {
    func log(_ level: LogLevel, _ message: @autoclosure () -> String) {}
}

actor MockEventSender: EventSending {
    func send(_ input: EventInput) async {}
}

actor CapturingEventSender: EventSending {
    var sentEvents: [EventInput] = []
    func send(_ input: EventInput) async {
        sentEvents.append(input)
    }
}
