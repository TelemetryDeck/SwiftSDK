import Foundation
import Testing

@testable import TelemetryDeck

struct TelemetryDeckTests {
    @Test
    func sending() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let config = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        TelemetryDeck.initialize(config: config)
        TelemetryDeck.signal("appOpenedRegularly")
        TelemetryDeck.signal("userLoggedIn", customUserID: "email")
        TelemetryDeck.signal("databaseUpdated", parameters: ["numberOfDatabaseEntries": "3831"])
    }

    @Test
    func pushAndPop() {
        let signalCache = SignalCache<SignalPostBody>(logHandler: nil)

        let signals: [SignalPostBody] = [
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "01",
                sessionID: "01",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "02",
                sessionID: "02",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "03",
                sessionID: "03",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "04",
                sessionID: "04",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "05",
                sessionID: "05",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "06",
                sessionID: "06",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "07",
                sessionID: "07",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "08",
                sessionID: "08",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "09",
                sessionID: "09",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "10",
                sessionID: "10",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "11",
                sessionID: "11",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "12",
                sessionID: "12",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "13",
                sessionID: "13",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "14",
                sessionID: "14",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
            .init(
                receivedAt: Date(),
                appID: UUID().uuidString,
                clientUser: "15",
                sessionID: "15",
                type: "test",
                floatValue: nil,
                payload: [:],
                isTestMode: "true"
            ),
        ]

        for signal in signals {
            signalCache.push(signal)
        }

        var allPoppedSignals: [SignalPostBody] = []
        var poppedSignalsBatch: [SignalPostBody] = signalCache.pop()
        while !poppedSignalsBatch.isEmpty {
            allPoppedSignals.append(contentsOf: poppedSignalsBatch)
            poppedSignalsBatch = signalCache.pop()
        }

        #expect(signals.count == allPoppedSignals.count)

        allPoppedSignals.sort { lhs, rhs in
            lhs.type < rhs.type
        }

        #expect(signals == allPoppedSignals)
    }

    @Test(.disabled("this test is flaky"), .bug("https://github.com/TelemetryDeck/SwiftSDK/issues/200"))
    func signalEnrichers() throws {
        struct BasicEnricher: SignalEnricher {
            func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
                ["isTestEnricher": "true"]
            }
        }

        let configuration = TelemetryManagerConfiguration(appID: UUID().uuidString)
        configuration.metadataEnrichers.append(BasicEnricher())

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        TelemetryDeck.signal("testSignal")

        let bodyItems = signalManager.processedSignals
        #expect(bodyItems.count == 1)
        let bodyItem = try #require(bodyItems.first)
        #expect(bodyItem.payload["isTestEnricher"] == "true")
    }

    @Test(.disabled("this test is flaky"), .bug("https://github.com/TelemetryDeck/SwiftSDK/issues/200"))
    func signalEnrichers_precedence() throws {
        struct BasicEnricher: SignalEnricher {
            func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
                ["item": "A", "isDebug": "banana"]
            }
        }

        let configuration = TelemetryManagerConfiguration(appID: UUID().uuidString)
        configuration.metadataEnrichers.append(BasicEnricher())

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        TelemetryDeck.signal("testSignal", parameters: ["item": "B"])

        let bodyItems = signalManager.processedSignals
        #expect(bodyItems.count == 1)
        let bodyItem = try #require(bodyItems.first)
        #expect(bodyItem.payload["item"] == "B")  // .send takes priority over enricher
        #expect(bodyItem.payload["isDebug"] == "banana")  // enricher takes priority over default payload
    }

    @Test(.disabled("this test is flaky"), .bug("https://github.com/TelemetryDeck/SwiftSDK/issues/200"))
    func sendsSignals_withAnalyticsImplicitlyEnabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)

        TelemetryDeck.signal("appOpenedRegularly")

        #expect(signalManager.processedSignalTypes.count == 1)
    }

    @Test(.disabled("this test is flaky"), .bug("https://github.com/TelemetryDeck/SwiftSDK/issues/200"))
    func sendsSignals_withAnalyticsExplicitlyEnabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = false

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)

        TelemetryDeck.signal("appOpenedRegularly")

        #expect(signalManager.processedSignalTypes.count == 1)
    }

    @Test
    func doesNotSendSignals_withAnalyticsExplicitlyDisabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = true

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)

        TelemetryDeck.signal("appOpenedRegularly")

        #expect(signalManager.processedSignalTypes.isEmpty == true)
    }

    @Test
    func doesNotSendSignals_withAnalyticsExplicitlyEnabled_inPreviewMode() {
        setenv("XCODE_RUNNING_FOR_PREVIEWS", "1", 1)

        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = false

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)

        TelemetryDeck.signal("appOpenedRegularly")

        #expect(signalManager.processedSignalTypes.isEmpty == true)

        setenv("XCODE_RUNNING_FOR_PREVIEWS", "0", 1)
    }

    @Test(.disabled("this test is flaky"), .bug("https://github.com/TelemetryDeck/SwiftSDK/issues/200"))
    func sendsSignals_withNumercalValue() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)

        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)

        TelemetryDeck.signal("appOpenedRegularly", floatValue: 42)

        #expect(signalManager.processedSignals.first?.floatValue == 42)
    }
}

private class FakeSignalManager: @preconcurrency SignalManageable {
    var processedSignalTypes: [String] = []
    var processedSignals: [SignalPostBody] = []

    @MainActor
    func processSignal(
        _ signalType: String,
        parameters: [String: String],
        floatValue: Double?,
        customUserID: String?,
        configuration: TelemetryManagerConfiguration
    ) {
        processedSignalTypes.append(signalType)
        let enrichedMetadata: [String: String] = configuration.metadataEnrichers
            .map { $0.enrich(signalType: signalType, for: customUserID, floatValue: floatValue) }
            .reduce([String: String]()) { $0.applying($1) }

        let payload = DefaultSignalPayload.parameters
            .applying(enrichedMetadata)
            .applying(parameters)

        let signalPostBody = SignalPostBody(
            receivedAt: Date(),
            appID: configuration.telemetryAppID,
            clientUser: customUserID ?? "no user",
            sessionID: configuration.sessionID.uuidString,
            type: "\(signalType)",
            floatValue: floatValue,
            payload: payload,
            isTestMode: configuration.testMode ? "true" : "false"
        )
        processedSignals.append(signalPostBody)
    }

    func attemptToSendNextBatchOfCachedSignals() {}

    var defaultUserIdentifier: String { UUID().uuidString }
}
