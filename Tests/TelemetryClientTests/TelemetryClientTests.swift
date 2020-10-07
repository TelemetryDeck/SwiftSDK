import XCTest
@testable import TelemetryClient

final class TelemetryClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual("Hello, World!", "Hello, World!")
        
        
        let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
        TelemetryManager.initialize(with: configuration)
        TelemetryManager.shared.send("appOpenedRegularly")
        TelemetryManager.shared.send("userLoggedIn", for: "email")
        TelemetryManager.shared.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])

    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
