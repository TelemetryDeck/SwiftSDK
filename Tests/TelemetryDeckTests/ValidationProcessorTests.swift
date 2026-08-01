import Foundation
import Testing

@testable import TelemetryDeck

private final class Locked<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

final class SpyLogger: Logging, @unchecked Sendable {
    private let logCalls = Locked<[(level: LogLevel, message: String)]>([])

    func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        logCalls.withLock { $0.append((level, message())) }
    }

    func errorMessages() -> [String] {
        logCalls.withLock { calls in
            calls.filter { $0.level == .error }.map { $0.message }
        }
    }

    func hasErrorContaining(_ substring: String) -> Bool {
        errorMessages().contains { $0.contains(substring) }
    }

    func clear() {
        logCalls.withLock { $0.removeAll() }
    }
}

struct ValidationProcessorTests {
    @Test
    func signalWithTelemetryDeckPrefixLogsError() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("TelemetryDeck.Custom.thing")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let hasError = logger.hasErrorContaining("TelemetryDeck.Custom.thing")
        #expect(hasError)

        let hasReservedPrefix = logger.hasErrorContaining("reserved prefix")
        #expect(hasReservedPrefix)
    }

    @Test
    func signalWithReservedNameLogsError() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("platform")
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let hasError = logger.hasErrorContaining("platform")
        #expect(hasError)

        let hasReservedName = logger.hasErrorContaining("reserved name")
        #expect(hasReservedName)
    }

    @Test
    func parameterWithTelemetryDeckPrefixLogsError() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("MyApp.event", parameters: ["TelemetryDeck.foo": "bar"])
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let hasError = logger.hasErrorContaining("TelemetryDeck.foo")
        #expect(hasError)

        let hasReservedPrefix = logger.hasErrorContaining("reserved prefix")
        #expect(hasReservedPrefix)
    }

    @Test
    func parameterWithReservedNameLogsError() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("MyApp.event", parameters: ["appVersion": "1.0.0"])
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let hasError = logger.hasErrorContaining("appVersion")
        #expect(hasError)

        let hasReservedName = logger.hasErrorContaining("reserved name")
        #expect(hasReservedName)
    }

    @Test
    func validSignalAndParametersPassWithoutLogging() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("MyApp.event", parameters: ["myKey": "myValue"])
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        let errorMessages = logger.errorMessages()
        #expect(errorMessages.isEmpty)
    }

    @Test
    func skipsReservedPrefixValidationForEventName() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("TelemetryDeck.Session.started", skipsReservedPrefixValidation: true)
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        #expect(logger.errorMessages().isEmpty)
    }

    @Test
    func skipsReservedPrefixValidationForParameterKey() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("MyApp.event", parameters: ["TelemetryDeck.Activation.featureName": "photos"], skipsReservedPrefixValidation: true)
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        #expect(logger.errorMessages().isEmpty)
    }

    @Test
    func reservedKeyValidationStillActiveWhenSkippingPrefix() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("platform", parameters: ["appVersion": "1.0"], skipsReservedPrefixValidation: true)
        let context = EventContext()
        _ = try await pipeline.process(input, context: context)

        #expect(logger.errorMessages().count == 2)
    }

    @Test
    func validationDoesNotFilterSignal() async throws {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test")
        let logger = SpyLogger()
        let processor = ValidationProcessor()
        await processor.start(storage: InMemoryProcessorStorage(), logger: logger, emitter: MockEventSender())

        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: config)
        )

        let input = EventInput("TelemetryDeck.Invalid", parameters: ["TelemetryDeck.bad": "value", "platform": "iOS"])
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.type == "TelemetryDeck.Invalid")
        #expect(signal.payload["TelemetryDeck.bad"] == "value")
        #expect(signal.payload["platform"] == "iOS")

        let errorMessages = logger.errorMessages()
        #expect(errorMessages.count == 3)
    }
}
