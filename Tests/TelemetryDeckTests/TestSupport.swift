import Foundation

@testable import TelemetryDeck

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

final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_767_225_600)) {
        self.current = start
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }

    var dateProvider: DateProvider {
        DateProvider { [self] in self.now }
    }
}
