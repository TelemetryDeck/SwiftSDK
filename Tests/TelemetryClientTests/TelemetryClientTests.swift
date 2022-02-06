@testable import TelemetryClient
import XCTest

final class TelemetryClientTests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual("Hello, World!", "Hello, World!")
        let YOUR_APP_ID = "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3"

        let configuration = TelemetryManagerConfiguration(appID: YOUR_APP_ID)
        TelemetryManager.initialize(with: configuration)
        TelemetryManager.send("appOpenedRegularly")
        TelemetryManager.send("userLoggedIn", for: "email")
        TelemetryManager.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])
    }
    
    func testPushAndPop() {
        let signalCache = SignalCache<SignalPostBody>(showDebugLogs: false)
        
        let signals: [SignalPostBody] = [
            .init(receivedAt: Date(), appID: UUID(), clientUser: "01", sessionID: "01", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "02", sessionID: "02", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "03", sessionID: "03", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "04", sessionID: "04", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "05", sessionID: "05", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "06", sessionID: "06", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "07", sessionID: "07", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "08", sessionID: "08", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "09", sessionID: "09", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "10", sessionID: "10", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "11", sessionID: "11", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "12", sessionID: "12", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "13", sessionID: "13", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "14", sessionID: "14", type: "test", payload: [], isTestMode: "true"),
            .init(receivedAt: Date(), appID: UUID(), clientUser: "15", sessionID: "15", type: "test", payload: [], isTestMode: "true")
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
}
