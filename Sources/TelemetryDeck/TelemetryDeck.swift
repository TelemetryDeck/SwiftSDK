import Foundation

private actor TelemetryDeckStorage {
    var client: TelemetryEngine?
    var logger: any Logging = DefaultLogger()
    private var buffer: [EventInput] = []

    func setClient(_ client: TelemetryEngine?) {
        self.client = client
    }

    func setLogger(_ logger: any Logging) {
        self.logger = logger
    }

    func send(_ input: EventInput) async {
        if let client {
            await client.send(input)
        } else {
            buffer.append(input)
        }
    }

    func drainBuffer() async {
        guard let client, !buffer.isEmpty else { return }
        let pending = buffer
        buffer = []
        logger.log(.debug, "Draining buffer with \(pending.count) events")
        for input in pending {
            await client.send(input)
        }
    }

    func clearBuffer() {
        buffer = []
    }
}

private let storage = TelemetryDeckStorage()

/// The primary namespace for the TelemetryDeck SDK, providing static methods for initialisation, event sending, and session management.
///
public enum TelemetryDeck {

    /// Returns the default set of event processors used when initialising without a custom processor list.
    public static func defaultProcessors(
        defaultUser: String? = nil,
        testMode: Bool? = nil,
        eventPrefix: String? = nil,
        parameterPrefix: String? = nil,
        sendSessionStartedEvent: Bool = true,
        defaultParameters: EventParameters = [:]
    ) -> [any EventProcessor] {
        buildProcessorList(
            sessionProcessor: SessionTrackingProcessor(sendSessionStartedEvent: sendSessionStartedEvent),
            defaultUser: defaultUser,
            testMode: testMode,
            eventPrefix: eventPrefix,
            parameterPrefix: parameterPrefix,
            defaultParameters: defaultParameters
        )
    }

    /// Returns the default event processors for in-memory-only mode.
    public static func defaultInMemoryProcessors(
        defaultUser: String? = nil,
        testMode: Bool? = nil,
        eventPrefix: String? = nil,
        parameterPrefix: String? = nil,
        sendSessionStartedEvent: Bool = true,
        defaultParameters: EventParameters = [:]
    ) -> [any EventProcessor] {
        buildProcessorList(
            sessionProcessor: InMemorySessionProcessor(sendSessionStartedEvent: sendSessionStartedEvent),
            defaultUser: defaultUser,
            testMode: testMode,
            eventPrefix: eventPrefix,
            parameterPrefix: parameterPrefix,
            defaultParameters: defaultParameters
        )
    }

    private static func buildProcessorList(
        sessionProcessor: any EventProcessor,
        defaultUser: String?,
        testMode: Bool?,
        eventPrefix: String?,
        parameterPrefix: String?,
        defaultParameters: EventParameters
    ) -> [any EventProcessor] {
        var processors: [any EventProcessor] = [
            PreviewFilterProcessor(),
            DefaultParametersProcessor(parameters: defaultParameters),
            DefaultPrefixProcessor(eventPrefix: eventPrefix, parameterPrefix: parameterPrefix),
            ValidationProcessor(),
            TestModeProcessor(override: testMode),
            UserIdentifierProcessor(defaultUser: defaultUser),
            sessionProcessor,
            DeviceProcessor(),
            AppInfoProcessor(),
            LocaleProcessor(),
            CalendarProcessor(),
            AccessibilityProcessor(),
            DisplayProcessor(),
        ]

        #if canImport(MetricKit) && !os(tvOS) && !os(watchOS) && !os(visionOS)
            if #available(iOS 27, macOS 27, macCatalyst 27, *) {
                processors.append(MetricKitProcessor())
            }
        #endif

        return processors
    }

    /// Initialises the SDK with the given app identity and processor-level options.
    ///
    /// When `inMemoryOnly` is `true`, the SDK uses in-memory storage only. Features that require persistent storage are disabled.
    @concurrent
    public static func initialize(
        appID: String,
        namespace: String,
        salt: String = "",
        defaultUser: String? = nil,
        testMode: Bool? = nil,
        eventPrefix: String? = nil,
        parameterPrefix: String? = nil,
        sendSessionStartedEvent: Bool = true,
        defaultParameters: EventParameters = [:],
        inMemoryOnly: Bool = false
    ) async throws(TelemetryDeckError) {
        let configuration = Config(appID: appID, namespace: namespace, salt: salt)
        if inMemoryOnly {
            try await initialize(
                configuration: configuration,
                processors: defaultInMemoryProcessors(
                    defaultUser: defaultUser,
                    testMode: testMode,
                    eventPrefix: eventPrefix,
                    parameterPrefix: parameterPrefix,
                    sendSessionStartedEvent: sendSessionStartedEvent,
                    defaultParameters: defaultParameters
                ),
                cache: InMemoryEventCache(),
                storage: InMemoryProcessorStorage()
            )
        } else {
            try await initialize(
                configuration: configuration,
                processors: defaultProcessors(
                    defaultUser: defaultUser,
                    testMode: testMode,
                    eventPrefix: eventPrefix,
                    parameterPrefix: parameterPrefix,
                    sendSessionStartedEvent: sendSessionStartedEvent,
                    defaultParameters: defaultParameters
                )
            )
        }
    }

    /// Initialises the SDK with the given configuration, optionally overriding processors and dependencies.
    ///
    /// `processors` defaults to `defaultProcessors()` when `nil`.
    @concurrent
    public static func initialize(
        configuration: Config,
        processors: [any EventProcessor]? = nil,
        cache: (any EventCaching)? = nil,
        transmitter: (any EventTransmitting)? = nil,
        logger: (any Logging)? = nil,
        storage processorStorage: (any ProcessorStorage)? = nil
    ) async throws(TelemetryDeckError) {
        try configuration.validate()
        let processors = processors ?? defaultProcessors()

        guard await storage.client == nil else {
            await log(.error, "TelemetryDeck.initialize() called more than once. Ignoring subsequent call. Remove the duplicate initialization.")
            return
        }

        let resolvedLogger = logger ?? DefaultLogger()
        await storage.setLogger(resolvedLogger)

        let client = await TelemetryEngine.create(
            configuration: configuration,
            processors: processors,
            cache: cache,
            transmitter: transmitter,
            logger: resolvedLogger,
            storage: processorStorage
        )
        await storage.setClient(client)
        await storage.drainBuffer()
    }

    static func client() async -> TelemetryEngine? {
        await storage.client
    }

    // Not @concurrent: the @autoclosure message parameter is non-Sendable, so call sites may capture actor-isolated state.
    static func log(_ level: LogLevel, _ message: @autoclosure () -> String) async {
        let logger = await storage.logger
        logger.log(level, message())
    }

    /// Sends an event whose name is provided as a raw-representable value.
    @concurrent
    public static func event<S: RawRepresentable>(
        _ name: S,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async where S.RawValue == String {
        await event(name.rawValue, parameters: parameters, floatValue: floatValue, customUserID: customUserID)
    }

    /// Sends an event with the given name, parameters, optional float value, and optional user ID override.
    @concurrent
    public static func event(
        _ name: String,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async {
        let input = EventInput(
            name,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID
        )
        await storage.send(input)
    }

    static func sdkEvent<S: RawRepresentable>(
        _ name: S,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async where S.RawValue == String {
        await sdkEvent(name.rawValue, parameters: parameters, floatValue: floatValue, customUserID: customUserID)
    }

    static func sdkEvent(
        _ name: String,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) async {
        let input = EventInput(
            name,
            parameters: parameters,
            floatValue: floatValue,
            customUserID: customUserID,
            skipsReservedPrefixValidation: true
        )
        await storage.send(input)
    }

    /// Sends an event without awaiting completion; suitable for fire-and-forget usage.
    public static func event(
        _ name: String,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) {
        Task { await event(name, parameters: parameters, floatValue: floatValue, customUserID: customUserID) }
    }

    /// Sends an event whose name is a raw-representable value without awaiting completion.
    public static func event<S: RawRepresentable>(
        _ name: S,
        parameters: EventParameters = [:],
        floatValue: Double? = nil,
        customUserID: String? = nil
    ) where S.RawValue == String {
        let rawName = name.rawValue
        event(rawName, parameters: parameters, floatValue: floatValue, customUserID: customUserID)
    }

    /// Immediately transmits all queued events without waiting for the next scheduled interval.
    @concurrent
    public static func flush() async {
        guard let client = await storage.client else { return }
        await client.flush()
    }

    /// Flushes pending events, shuts down the engine, and clears the shared instance.
    @concurrent
    public static func terminate() async {
        if let client = await storage.client {
            await client.flush()
            await client.shutdown()
        }
        await storage.setClient(nil)
        await storage.clearBuffer()
    }

    // MARK: - Analytics Disabled

    /// Enables or disables analytics collection; while disabled, events are silently dropped.
    @concurrent
    public static func setAnalyticsDisabled(_ disabled: Bool) async {
        guard let client = await storage.client else { return }
        await client.setAnalyticsDisabled(disabled)
    }

    /// Whether analytics collection is currently disabled.
    @concurrent
    public static var isAnalyticsDisabled: Bool {
        get async {
            guard let client = await storage.client else { return false }
            return await client.isAnalyticsDisabled
        }
    }

    // MARK: - User Identifier

    /// Sets the user identifier applied to all subsequent events; pass `nil` to revert to the default.
    @concurrent
    public static func setUserIdentifier(_ value: String?) async {
        guard let client = await storage.client else {
            await log(.error, "TelemetryDeck not initialized")
            return
        }
        if let processor = await client.processor(conformingTo: (any UserIdentifierManaging).self) {
            await processor.setUserIdentifier(value)
        } else {
            await log(.error, "No UserIdentifierManaging processor in pipeline")
        }
    }

    // MARK: - Session

    /// The identifier of the current session, or `nil` if the SDK has not been initialised.
    @concurrent
    public static var sessionID: UUID? {
        get async {
            guard let client = await storage.client else { return nil }
            guard let processor = await client.processor(conformingTo: (any SessionManaging).self) else {
                return nil
            }
            return await processor.currentSessionID()
        }
    }

    /// Starts a new session and returns its identifier, or `nil` if the SDK is not initialised.
    @discardableResult
    @concurrent
    public static func newSession() async -> UUID? {
        guard let client = await storage.client else {
            await log(.error, "TelemetryDeck not initialized")
            return nil
        }
        guard let sessionProcessor = await client.processor(conformingTo: (any SessionManaging).self) else {
            await log(.error, "No SessionManaging processor in pipeline")
            return nil
        }
        return await sessionProcessor.startNewSession()
    }

    // MARK: - Test Mode

    /// Returns whether the SDK is currently operating in test mode.
    @concurrent
    public static func isTestMode() async -> Bool {
        guard let client = await storage.client else { return false }
        guard let processor = await client.processor(conformingTo: (any TestModeProviding).self) else {
            return false
        }
        return await processor.isTestMode()
    }

    // MARK: - Duration Tracking

    /// Begins measuring elapsed time for the named event, optionally including time spent in the background.
    @concurrent
    public static func startDurationEvent(
        _ eventName: String,
        parameters: EventParameters = [:],
        includeBackgroundTime: Bool = false
    ) async {
        guard let client = await storage.client else {
            await log(.error, "TelemetryDeck not initialized")
            return
        }
        await client.durationTracker.startDuration(
            eventName,
            parameters: parameters,
            includeBackgroundTime: includeBackgroundTime
        )
    }

    /// Stops the duration measurement for the named event and sends the event with the elapsed time as a parameter and float value.
    @concurrent
    public static func stopAndSendDurationEvent(
        _ eventName: String,
        parameters: EventParameters = [:]
    ) async {
        guard let client = await storage.client else {
            await log(.error, "TelemetryDeck not initialized")
            return
        }
        guard let result = await client.durationTracker.stopDuration(eventName) else { return }
        let roundedDuration = (result.durationInSeconds * 1_000).rounded(.down) / 1_000

        var mergedParams: EventParameters = [DefaultParams.Event.durationInSeconds.rawValue: roundedDuration]
        mergedParams.merge(result.startParameters)
        mergedParams.merge(parameters)

        await event(eventName, parameters: mergedParams, floatValue: roundedDuration)
    }

    /// Cancels an in-progress duration measurement without sending an event.
    @concurrent
    public static func cancelDurationEvent(_ eventName: String) async {
        guard let client = await storage.client else { return }
        await client.durationTracker.cancelDuration(eventName)
    }
}
