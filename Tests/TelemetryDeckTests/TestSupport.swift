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

func makeEvent(type: String = "Test.signal") -> Event {
    Event(
        appID: "test-app",
        type: type,
        clientUser: "test-user-hash",
        sessionID: UUID().uuidString,
        receivedAt: Date(),
        payload: [:],
        floatValue: nil,
        isTestMode: true
    )
}

final class ScriptedHTTPClient: HTTPDataLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [Data] = []
    private var statusCodes: [Int] = []
    private var waiting: [CheckedContinuation<Int, Never>] = []
    private var arrivalWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var cancellations = 0

    var cancelledRequestCount: Int {
        lock.withLock { cancellations }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let statusCode = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let (immediate, arrived) = lock.withLock { () -> (Int?, [CheckedContinuation<Void, Never>]) in
                bodies.append(request.httpBody ?? Data())
                let arrived = arrivalWaiters.filter { $0.count <= bodies.count }.map(\.continuation)
                arrivalWaiters.removeAll { $0.count <= bodies.count }
                guard statusCodes.isEmpty else {
                    return (statusCodes.removeFirst(), arrived)
                }
                waiting.append(continuation)
                return (nil, arrived)
            }
            for waiter in arrived {
                waiter.resume()
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
        if Task.isCancelled {
            lock.withLock { cancellations += 1 }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }

    func respond(statusCode: Int) {
        let continuation = lock.withLock { () -> CheckedContinuation<Int, Never>? in
            guard !waiting.isEmpty else {
                statusCodes.append(statusCode)
                return nil
            }
            return waiting.removeFirst()
        }
        continuation?.resume(returning: statusCode)
    }

    func waitForRequests(_ count: Int) async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            let arrived = lock.withLock {
                guard bodies.count >= count else {
                    arrivalWaiters.append((count, waiter))
                    return false
                }
                return true
            }
            if arrived {
                waiter.resume()
            }
        }
    }

    func sentEventTypes() throws -> [[String]] {
        try lock.withLock { bodies }.map { body in
            let events = try JSONSerialization.jsonObject(with: body) as? [[String: Any]] ?? []
            return events.compactMap { $0["type"] as? String }
        }
    }
}
