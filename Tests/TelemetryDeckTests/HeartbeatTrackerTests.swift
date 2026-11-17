import Foundation
import Testing

@testable import TelemetryDeck

private final class ManualSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UUID: (delay: TimeInterval, continuation: CheckedContinuation<Void, any Error>)] = [:]
    private var cancelledIDs: Set<UUID> = []
    private var sleepWaiters: [CheckedContinuation<TimeInterval, Never>] = []

    var pendingCount: Int {
        lock.withLock { pending.count }
    }

    func sleep(_ delay: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let waiters: [CheckedContinuation<TimeInterval, Never>] = lock.withLock {
                    if cancelledIDs.remove(id) != nil {
                        continuation.resume(throwing: CancellationError())
                        return []
                    }
                    pending[id] = (delay, continuation)
                    defer { sleepWaiters = [] }
                    return sleepWaiters
                }
                for waiter in waiters {
                    waiter.resume(returning: delay)
                }
            }
        } onCancel: {
            let continuation: CheckedContinuation<Void, any Error>? = lock.withLock {
                guard let entry = pending.removeValue(forKey: id) else {
                    cancelledIDs.insert(id)
                    return nil
                }
                return entry.continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    func nextSleep() async -> TimeInterval {
        await withCheckedContinuation { (waiter: CheckedContinuation<TimeInterval, Never>) in
            let delay: TimeInterval? = lock.withLock {
                guard let entry = pending.values.first else {
                    sleepWaiters.append(waiter)
                    return nil
                }
                return entry.delay
            }
            if let delay {
                waiter.resume(returning: delay)
            }
        }
    }

    func fire(sourceLocation: SourceLocation = #_sourceLocation) {
        let continuations = lock.withLock {
            defer { pending = [:] }
            return pending.values.map(\.continuation)
        }
        if continuations.count != 1 {
            Issue.record("Expected exactly one pending sleep, found \(continuations.count)", sourceLocation: sourceLocation)
        }
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private final class Checkpoint: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var hasArrival = false
    private var passers: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []

    func pass() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let (passesNow, waiters) = lock.withLock { () -> (Bool, [CheckedContinuation<Void, Never>]) in
                hasArrival = true
                defer { arrivalWaiters = [] }
                if !isOpen {
                    passers.append(continuation)
                }
                return (isOpen, arrivalWaiters)
            }
            for waiter in waiters {
                waiter.resume()
            }
            if passesNow {
                continuation.resume()
            }
        }
    }

    func waitForArrival() async {
        await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
            let arrived = lock.withLock {
                if !hasArrival {
                    arrivalWaiters.append(waiter)
                }
                return hasArrival
            }
            if arrived {
                waiter.resume()
            }
        }
    }

    func open() {
        let continuations = lock.withLock {
            isOpen = true
            defer { passers = [] }
            return passers
        }
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private actor GatedEventSender: EventSending {
    private(set) var sentEvents: [EventInput] = []
    private let gate: Checkpoint?

    init(gate: Checkpoint?) {
        self.gate = gate
    }

    func send(_ input: EventInput) async {
        sentEvents.append(input)
        await gate?.pass()
    }
}

private final class ActivityProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var active: Bool
    private var queries = 0

    init(active: Bool) {
        self.active = active
    }

    var queryCount: Int {
        lock.withLock { queries }
    }

    func isActive() -> Bool {
        lock.withLock {
            queries += 1
            return active
        }
    }
}

private final class LifecycleFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<LifecycleEvent>.Continuation?

    func events() -> AsyncStream<LifecycleEvent> {
        let (stream, continuation) = AsyncStream<LifecycleEvent>.makeStream()
        lock.withLock { self.continuation = continuation }
        return stream
    }

    func post(_ event: LifecycleEvent) {
        let continuation = lock.withLock { self.continuation }
        continuation?.yield(event)
    }
}

@Suite
struct HeartbeatTrackerTests {
    private struct Harness {
        let clock = MutableClock()
        let sleeper = ManualSleeper()
        let sender: GatedEventSender
        let tracker: HeartbeatTracker
        let probe: ActivityProbe
        let lifecycle = LifecycleFeed()

        init(
            active: Bool = true,
            activityGate: Checkpoint? = nil,
            timerGate: Checkpoint? = nil,
            sendGate: Checkpoint? = nil
        ) async {
            let clock = clock
            let sleeper = sleeper
            let lifecycle = lifecycle
            let probe = ActivityProbe(active: active)
            self.probe = probe
            sender = GatedEventSender(gate: sendGate)
            tracker = HeartbeatTracker(
                uptime: { clock.now.timeIntervalSinceReferenceDate },
                sleep: { delay in
                    try await sleeper.sleep(delay)
                    await timerGate?.pass()
                },
                isAppActive: {
                    await activityGate?.pass()
                    return probe.isActive()
                },
                lifecycleEvents: { lifecycle.events() }
            )
            await tracker.start(emitter: sender)
        }

        func elapse(_ seconds: TimeInterval) async {
            clock.advance(by: seconds)
            sleeper.fire()
            _ = await sleeper.nextSleep()
        }

        func eventCount() async -> Int {
            await sender.sentEvents.count
        }

        func settle() async {
            for _ in 0..<200 {
                await Task.yield()
            }
        }
    }

    @Test
    func firstHeartbeatIsSentOnlyAfterAFullInterval() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)

        #expect(await harness.sleeper.nextSleep() == 60)
        #expect(await harness.eventCount() == 0)

        await harness.elapse(30)
        #expect(await harness.eventCount() == 0)
        #expect(await harness.sleeper.nextSleep() == 30)

        await harness.elapse(30)
        #expect(await harness.eventCount() == 1)
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.tracker.stop()
    }

    @Test
    func heartbeatsRepeatEveryInterval() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        await harness.elapse(60)
        await harness.elapse(60)
        await harness.elapse(60)

        #expect(await harness.eventCount() == 3)

        await harness.tracker.stop()
    }

    @Test
    func heartbeatUsesSessionHeartbeatEventAndSkipsReservedPrefixValidation() async throws {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        await harness.elapse(60)

        let event = try #require(await harness.sender.sentEvents.first)
        #expect(event.name == "TelemetryDeck.Session.heartbeat")
        #expect(event.skipsReservedPrefixValidation)
        #expect(event.parameters.payloadDictionary.isEmpty)

        await harness.tracker.stop()
    }

    @Test
    func secondStartHasNoEffect() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        #expect(harness.probe.queryCount == 1)
        #expect(harness.sleeper.pendingCount == 1)

        await harness.elapse(60)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func stopThenStartRestartsHeartbeats() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()
        harness.clock.advance(by: 45)

        await harness.tracker.stopHeartbeats()
        #expect(await harness.tracker.isRunning == false)
        #expect(harness.sleeper.pendingCount == 0)

        await harness.tracker.startHeartbeats(.minute)
        #expect(await harness.tracker.isRunning)
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.elapse(60)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func nothingIsSentWhileInactiveAndAccumulatedActiveTimeIsKept() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 50)
        await harness.tracker.handleBackground()
        #expect(harness.sleeper.pendingCount == 0)

        harness.clock.advance(by: 600)
        #expect(await harness.eventCount() == 0)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 10)

        await harness.elapse(10)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func startWhileInactiveSendsNothingUntilActive() async {
        let harness = await Harness(active: false)
        await harness.tracker.startHeartbeats(.minute)
        #expect(await harness.tracker.isRunning)

        harness.clock.advance(by: 300)
        #expect(harness.sleeper.pendingCount == 0)
        #expect(await harness.eventCount() == 0)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.elapse(60)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test(arguments: [120, 179.5, 3_600])
    func longGapWhileActiveSendsASingleHeartbeat(gap: TimeInterval) async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        await harness.elapse(gap)

        #expect(await harness.eventCount() == 1)
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.settle()
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func lateTimerWakesCarryExcessActiveTimeTowardTheNextHeartbeat() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        var delay = await harness.sleeper.nextSleep()
        var activeTime: TimeInterval = 0

        for _ in 0..<20 {
            let wake = delay + 3.75
            activeTime += wake
            harness.clock.advance(by: wake)
            harness.sleeper.fire()
            delay = await harness.sleeper.nextSleep()

            #expect(delay == 56.25)
            #expect(await harness.eventCount() == Int(activeTime / 60))
        }

        #expect(activeTime == 1_203.75)
        #expect(await harness.eventCount() == 20)

        await harness.tracker.stop()
    }

    @Test
    func excessBelowOneIntervalIsCarriedOverWithoutAnImmediateHeartbeat() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        await harness.elapse(119.5)

        #expect(await harness.eventCount() == 1)
        #expect(await harness.sleeper.nextSleep() == 0.5)

        await harness.elapse(0.5)
        #expect(await harness.eventCount() == 2)
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.tracker.stop()
    }

    @Test
    func backgroundCarriesExcessActiveTimeTowardTheNextHeartbeat() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 75)
        await harness.tracker.handleBackground()
        #expect(await harness.eventCount() == 1)

        harness.clock.advance(by: 600)
        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 45)

        harness.clock.advance(by: 50)
        await harness.tracker.handleBackground()
        #expect(await harness.eventCount() == 2)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 55)

        await harness.elapse(55)
        #expect(await harness.eventCount() == 3)

        await harness.tracker.stop()
    }

    @Test
    func backgroundAfterAFullIntervalSendsTheEarnedHeartbeat() async {
        let harness = await Harness()
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 60)
        await harness.tracker.handleBackground()
        #expect(await harness.eventCount() == 1)
        #expect(harness.sleeper.pendingCount == 0)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 60)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func backgroundLifecycleEventSendsEarnedHeartbeatAndStopsTimer() async {
        let sendGate = Checkpoint()
        let harness = await Harness(sendGate: sendGate)
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 60)
        harness.lifecycle.post(.background)
        await sendGate.waitForArrival()

        #expect(harness.sleeper.pendingCount == 0)
        #expect(await harness.eventCount() == 1)

        sendGate.open()
        await harness.tracker.stop()
    }

    @Test
    func timerCancelledAfterItsSleepEndedSendsNothing() async {
        let timerGate = Checkpoint()
        let harness = await Harness(timerGate: timerGate)
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 30)
        harness.sleeper.fire()
        await timerGate.waitForArrival()

        await harness.tracker.handleBackground()
        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 30)

        timerGate.open()
        await harness.settle()

        #expect(harness.sleeper.pendingCount == 1)
        #expect(await harness.eventCount() == 0)

        await harness.elapse(30)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func backgroundWhileHeartbeatIsBeingSentDoesNotRescheduleTimer() async {
        let sendGate = Checkpoint()
        let harness = await Harness(sendGate: sendGate)
        await harness.tracker.startHeartbeats(.minute)
        _ = await harness.sleeper.nextSleep()

        harness.clock.advance(by: 60)
        harness.sleeper.fire()
        await sendGate.waitForArrival()

        await harness.tracker.handleBackground()
        sendGate.open()
        await harness.settle()

        #expect(harness.sleeper.pendingCount == 0)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 60)
        #expect(harness.sleeper.pendingCount == 1)

        await harness.tracker.stop()
    }

    @Test
    func backgroundDuringInitialActivityQueryWinsOverStaleActiveState() async {
        let activityGate = Checkpoint()
        let harness = await Harness(active: true, activityGate: activityGate)
        let start = Task { await harness.tracker.startHeartbeats(.minute) }
        await activityGate.waitForArrival()

        await harness.tracker.handleBackground()
        activityGate.open()
        await start.value

        #expect(await harness.tracker.isRunning)
        #expect(harness.sleeper.pendingCount == 0)

        await harness.tracker.handleForeground()
        #expect(await harness.sleeper.nextSleep() == 60)

        await harness.tracker.stop()
    }

    @Test
    func foregroundDuringInitialActivityQueryWinsOverStaleInactiveState() async {
        let activityGate = Checkpoint()
        let harness = await Harness(active: false, activityGate: activityGate)
        let start = Task { await harness.tracker.startHeartbeats(.minute) }
        await activityGate.waitForArrival()

        await harness.tracker.handleForeground()
        activityGate.open()
        await start.value

        #expect(await harness.sleeper.nextSleep() == 60)
        await harness.elapse(60)
        #expect(await harness.eventCount() == 1)

        await harness.tracker.stop()
    }

    @Test
    func stopDuringInitialActivityQueryLeavesTrackerStopped() async {
        let activityGate = Checkpoint()
        let harness = await Harness(activityGate: activityGate)
        let start = Task { await harness.tracker.startHeartbeats(.minute) }
        await activityGate.waitForArrival()

        await harness.tracker.stop()
        activityGate.open()
        await start.value

        #expect(await harness.tracker.isRunning == false)
        #expect(harness.sleeper.pendingCount == 0)
    }

    @Test
    func startAfterStopHasNoEffect() async {
        let harness = await Harness()
        await harness.tracker.stop()

        await harness.tracker.startHeartbeats(.minute)

        #expect(await harness.tracker.isRunning == false)
        #expect(harness.probe.queryCount == 0)
        #expect(harness.sleeper.pendingCount == 0)
    }

    @Test
    func engineShutdownStopsHeartbeats() async {
        let engine = await TelemetryEngine.create(
            configuration: TelemetryDeck.Config(appID: "test-app", namespace: "test"),
            processors: [],
            cache: InMemoryEventCache(),
            transmitter: SpyEventTransmitter(),
            logger: NoOpLogger(),
            storage: InMemoryProcessorStorage()
        )
        await engine.heartbeatTracker.startHeartbeats(.minute)
        #expect(await engine.heartbeatTracker.isRunning)

        await engine.shutdown()

        #expect(await engine.heartbeatTracker.isRunning == false)
    }
}
