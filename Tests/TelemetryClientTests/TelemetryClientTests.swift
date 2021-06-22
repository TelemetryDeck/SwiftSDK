@testable import TelemetryClient
import XCTest

final class TelemetryClientTests: XCTestCase {
    static var allTests = [
        ("testExample", testExample),
        ("testPushAndPop", testPushAndPop),
    ]
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual("Hello, World!", "Hello, World!")

        let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
        TelemetryManager.initialize(with: configuration)
        TelemetryManager.send("appOpenedRegularly")
        TelemetryManager.send("userLoggedIn", for: "email")
        TelemetryManager.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])
    }
    
    func testPushAndPop() {
        let signalCache = SignalCache()
        
        let signals: [SignalPostBody] = [
            .init(receivedAt: Date(), type: "01", clientUser: "01", sessionID: "01", payload: nil),
            .init(receivedAt: Date(), type: "02", clientUser: "02", sessionID: "02", payload: nil),
            .init(receivedAt: Date(), type: "03", clientUser: "03", sessionID: "03", payload: nil),
            .init(receivedAt: Date(), type: "04", clientUser: "04", sessionID: "04", payload: nil),
            .init(receivedAt: Date(), type: "05", clientUser: "05", sessionID: "05", payload: nil),
            .init(receivedAt: Date(), type: "06", clientUser: "06", sessionID: "06", payload: nil),
            .init(receivedAt: Date(), type: "07", clientUser: "07", sessionID: "07", payload: nil),
            .init(receivedAt: Date(), type: "08", clientUser: "08", sessionID: "08", payload: nil),
            .init(receivedAt: Date(), type: "09", clientUser: "09", sessionID: "09", payload: nil),
            .init(receivedAt: Date(), type: "10", clientUser: "10", sessionID: "10", payload: nil),
            .init(receivedAt: Date(), type: "11", clientUser: "11", sessionID: "11", payload: nil),
            .init(receivedAt: Date(), type: "12", clientUser: "12", sessionID: "12", payload: nil),
            .init(receivedAt: Date(), type: "13", clientUser: "13", sessionID: "13", payload: nil),
            .init(receivedAt: Date(), type: "14", clientUser: "14", sessionID: "14", payload: nil),
            .init(receivedAt: Date(), type: "15", clientUser: "15", sessionID: "15", payload: nil)
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
