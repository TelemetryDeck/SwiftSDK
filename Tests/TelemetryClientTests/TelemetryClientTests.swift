import XCTest
@testable import TelemetryClient

final class TelemetryClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual("Hello, World!", "Hello, World!")
        
        
        let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
        let telemetryManager = TelemetryManager(configuration: configuration)
        telemetryManager.send("appOpenedRegularly")
        telemetryManager.send("userLoggedIn", for: "email")
        telemetryManager.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])

    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
