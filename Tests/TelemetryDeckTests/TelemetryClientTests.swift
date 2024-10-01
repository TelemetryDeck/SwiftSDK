@testable import TelemetryClient
import XCTest

final class TelemetryClientTests: XCTestCase {
    func testSending() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let config = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        TelemetryDeck.initialize(config: config)
        TelemetryDeck.signal("appOpenedRegularly")
        TelemetryDeck.signal("userLoggedIn", customUserID: "email")
        TelemetryDeck.signal("databaseUpdated", parameters: ["numberOfDatabaseEntries": "3831"])
    }
    
    func testPushAndPop() {
        let signalCache = SignalCache<SignalPostBody>(logHandler: nil)
        
        let signals: [SignalPostBody] = [
            .init(receivedAt: Date(), appID: UUID(), clientUser: "01", sessionID: "01", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "02", sessionID: "02", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "03", sessionID: "03", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "04", sessionID: "04", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "05", sessionID: "05", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "06", sessionID: "06", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "07", sessionID: "07", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "08", sessionID: "08", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "09", sessionID: "09", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "10", sessionID: "10", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "11", sessionID: "11", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "12", sessionID: "12", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "13", sessionID: "13", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "14", sessionID: "14", type: "test", floatValue: nil, payload: [:], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "15", sessionID: "15", type: "test", floatValue: nil, payload: [:], isTestMode: "true")
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
        
        XCTAssertEqual(signals.count, allPoppedSignals.count)
        
        allPoppedSignals.sort { lhs, rhs in
            lhs.type < rhs.type
        }
        
        XCTAssertEqual(signals, allPoppedSignals)
    }
    
    func testSignalEnrichers() throws {
        struct BasicEnricher: SignalEnricher {
            func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
                ["isTestEnricher": "true"]
            }
        }
        
        var configuration = TelemetryManagerConfiguration(appID: UUID().uuidString)
        configuration.metadataEnrichers.append(BasicEnricher())
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        TelemetryDeck.signal("testSignal")

        let bodyItems = signalManager.processedSignals
        XCTAssertEqual(bodyItems.count, 1)
        let bodyItem = try XCTUnwrap(bodyItems.first)
        XCTAssert(bodyItem.payload["isTestEnricher"] == "true")
    }
    
    func testSignalEnrichers_precedence() throws {
        struct BasicEnricher: SignalEnricher {
            func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
                ["item": "A", "isDebug": "banana"]
            }
        }
        
        var configuration = TelemetryManagerConfiguration(appID: UUID().uuidString)
        configuration.metadataEnrichers.append(BasicEnricher())
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        TelemetryDeck.signal("testSignal", parameters: ["item": "B"])

        let bodyItems = signalManager.processedSignals
        XCTAssertEqual(bodyItems.count, 1)
        let bodyItem = try XCTUnwrap(bodyItems.first)
        XCTAssert(bodyItem.payload["item"] == "B") // .send takes priority over enricher
        XCTAssert(bodyItem.payload["isDebug"] == "banana") // enricher takes priority over default payload
    }
    
    func testSendsSignals_withAnalyticsImplicitlyEnabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        
        TelemetryDeck.signal("appOpenedRegularly")
        
        XCTAssertEqual(signalManager.processedSignalTypes.count, 1)
    }
    
    func testSendsSignals_withAnalyticsExplicitlyEnabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        var configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = false
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        
        TelemetryDeck.signal("appOpenedRegularly")
        
        XCTAssertEqual(signalManager.processedSignalTypes.count, 1)
    }
    
    func testDoesNotSendSignals_withAnalyticsExplicitlyDisabled() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        var configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = true
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        
        TelemetryDeck.signal("appOpenedRegularly")
        
        XCTAssertTrue(signalManager.processedSignalTypes.isEmpty)
    }
    
    func testDoesNotSendSignals_withAnalyticsExplicitlyEnabled_inPreviewMode() {
        setenv("XCODE_RUNNING_FOR_PREVIEWS", "1", 1)

        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        var configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        configuration.analyticsDisabled = false
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        
        TelemetryDeck.signal("appOpenedRegularly")
        
        XCTAssertTrue(signalManager.processedSignalTypes.isEmpty)
        
        setenv("XCODE_RUNNING_FOR_PREVIEWS", "0", 1)
    }
    
    func testSendsSignals_withNumercalValue() {
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        
        let signalManager = FakeSignalManager()
        TelemetryManager.initialize(with: configuration, signalManager: signalManager)
        
        TelemetryDeck.signal("appOpenedRegularly", floatValue: 42)

        XCTAssertEqual(signalManager.processedSignals.first?.floatValue, 42)
    }
}

private class FakeSignalManager: SignalManageable {
    var processedSignalTypes = [String]()
    var processedSignals = [SignalPostBody]()
    
    @MainActor
    func processSignal(_ signalType: String, parameters: [String: String], floatValue: Double?, customUserID: String?, configuration: TelemetryManagerConfiguration) {
        processedSignalTypes.append(signalType)
        let enrichedMetadata: [String: String] = configuration.metadataEnrichers
            .map { $0.enrich(signalType: signalType, for: customUserID, floatValue: floatValue) }
            .reduce([String: String]()) { $0.applying($1) }
        
        let payload = DefaultSignalPayload.parameters
            .applying(enrichedMetadata)
            .applying(parameters)

        let signalPostBody = SignalPostBody(
            receivedAt: Date(),
            appID: UUID(uuidString: configuration.telemetryAppID)!,
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
}
