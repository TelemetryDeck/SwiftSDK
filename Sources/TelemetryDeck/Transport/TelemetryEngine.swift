import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit
#endif

/// The central coordinator that owns the processor pipeline, event cache, and transmitter.
actor TelemetryEngine: EventSending {
    let configuration: TelemetryDeck.Config
    private let processors: [any EventProcessor]
    private let pipeline: ProcessorPipeline
    private let cache: any EventCaching
    private let transmitter: any EventTransmitting
    private let logger: any Logging
    private let storage: any ProcessorStorage
    let durationTracker: DurationTracker
    private var analyticsDisabled = false
    private var started = false
    private var lifecycleTask: Task<Void, Never>?

    #if canImport(UIKit) && !os(watchOS)
        private final class BackgroundTaskHolder: @unchecked Sendable {
            var identifier = UIBackgroundTaskIdentifier.invalid
        }
    #endif

    private init(
        configuration: TelemetryDeck.Config,
        processors: [any EventProcessor],
        cache: any EventCaching,
        transmitter: any EventTransmitting,
        logger: any Logging,
        storage: any ProcessorStorage
    ) {
        self.configuration = configuration
        self.processors = processors
        self.cache = cache
        self.transmitter = transmitter
        self.logger = logger
        self.storage = storage
        self.durationTracker = DurationTracker()
        self.pipeline = ProcessorPipeline(
            processors: processors,
            finalizer: EventFinalizer(configuration: configuration)
        )
    }

    /// Creates, configures, and starts a `TelemetryEngine` with the provided or default dependencies.
    static func create(
        configuration: TelemetryDeck.Config,
        processors: [any EventProcessor],
        cache: (any EventCaching)? = nil,
        transmitter: (any EventTransmitting)? = nil,
        logger: (any Logging)? = nil,
        storage: (any ProcessorStorage)? = nil
    ) async -> TelemetryEngine {
        let resolvedLogger = logger ?? DefaultLogger()
        let resolvedCache = cache ?? DefaultEventCache()
        let appIdHash = CryptoHashing.sha256(string: configuration.appID, salt: "")
        let resolvedStorage =
            storage
            ?? UserDefaultsProcessorStorage(
                suiteName: "com.telemetrydeck.\(appIdHash.suffix(12))"
            )
        let resolvedTransmitter =
            transmitter
            ?? DefaultEventTransmitter(
                configuration: configuration,
                cache: resolvedCache,
                logger: resolvedLogger
            )

        let client = TelemetryEngine(
            configuration: configuration,
            processors: processors,
            cache: resolvedCache,
            transmitter: resolvedTransmitter,
            logger: resolvedLogger,
            storage: resolvedStorage
        )
        await client.start()
        return client
    }

    private func start() async {
        guard !started else { return }
        started = true
        await cache.restore()
        for processor in processors {
            await processor.start(storage: storage, logger: logger, emitter: self)
        }
        await durationTracker.start(storage: storage)
        await transmitter.start()
        setupLifecycleObservers()
    }

    /// Stops all processors and the transmitter, persists the cache, and cancels lifecycle observers.
    func shutdown() async {
        for processor in processors {
            await processor.stop()
        }
        await durationTracker.stop()
        await transmitter.stop()
        await cache.persist()
        lifecycleTask?.cancel()
        lifecycleTask = nil
        started = false
    }

    /// Processes the input through the pipeline and adds the resulting event to the cache.
    func send(_ input: EventInput) async {
        guard !analyticsDisabled else { return }
        let context = EventContext()
        do {
            let event = try await pipeline.process(input, context: context)
            await cache.add(event)
        } catch let error as ProcessorError {
            switch error {
            case .eventFiltered:
                logger.log(.debug, "Event filtered by processor pipeline")
            case .processingFailed(let underlying):
                logger.log(.error, "Pipeline processing failed: \(underlying)")
            }
        } catch {
            logger.log(.error, "Pipeline error: \(error)")
        }
    }

    /// Enables or disables analytics; while disabled, events are silently dropped.
    func setAnalyticsDisabled(_ disabled: Bool) {
        analyticsDisabled = disabled
    }

    /// Indicates whether analytics is currently disabled.
    var isAnalyticsDisabled: Bool {
        analyticsDisabled
    }

    /// Immediately transmits all cached events.
    func flush() async {
        await transmitter.flush()
    }

    /// Returns the first processor in the pipeline that is exactly of the given concrete type.
    func processor<T: EventProcessor>(ofType type: T.Type) -> T? {
        processors.first { $0 is T } as? T
    }

    /// Returns the first processor in the pipeline that conforms to the given protocol.
    func processor<T>(conformingTo type: T.Type) -> T? {
        processors.first { $0 is T } as? T
    }

    private func handleBackground() async {
        #if canImport(UIKit) && !os(watchOS)
            if !Environment.isAppExtension {
                let app = await MainActor.run { UIApplication.shared }
                let holder = BackgroundTaskHolder()
                holder.identifier = await MainActor.run {
                    app.beginBackgroundTask {
                        app.endBackgroundTask(holder.identifier)
                    }
                }
                await transmitter.stop()
                await cache.persist()
                await MainActor.run {
                    app.endBackgroundTask(holder.identifier)
                }
            } else {
                await transmitter.stop()
                await cache.persist()
            }
        #else
            await transmitter.stop()
            await cache.persist()
        #endif
    }

    private func handleForeground() async {
        await cache.restore()
        await transmitter.start()
    }

    private func handleTermination() async {
        await cache.persist()
        await transmitter.stop()
    }

    private func setupLifecycleObservers() {
        lifecycleTask = Task {
            for await event in LifecycleNotifier.events() {
                switch event {
                case .background:
                    await handleBackground()
                case .foreground:
                    await handleForeground()
                case .termination:
                    await handleTermination()
                }
            }
        }
    }
}
