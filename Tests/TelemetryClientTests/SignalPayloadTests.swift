@testable import TelemetryClient
import XCTest

final class SignalPayloadTests: XCTestCase {
    func testIsSimulatorOrTestFlight() {
        XCTAssertNoThrow(SignalPayload.isSimulatorOrTestFlight)
        print("isSimulatorOrTestFlight", SignalPayload.isSimulatorOrTestFlight)
    }
    
    func testIsSimulator() {
        XCTAssertNoThrow(SignalPayload.isSimulator)
        print("isSimulator", SignalPayload.isSimulator)
    }
    
    func testIsDebug() {
        XCTAssertTrue(SignalPayload.isDebug)
        print("isDebug", SignalPayload.isDebug)
    }
    
    func testIsTestFlight() {
        XCTAssertFalse(SignalPayload.isTestFlight)
        print("isTestFlight", SignalPayload.isTestFlight)
    }
    
    func testIsAppStore() {
        XCTAssertFalse(SignalPayload.isAppStore)
        print("isAppStore", SignalPayload.isAppStore)
    }
    
    func testSystemVersion() {
        XCTAssertNoThrow(SignalPayload.systemVersion)
        print("systemVersion", SignalPayload.systemVersion)
    }
    
    func testMajorSystemVersion() {
        XCTAssertNoThrow(SignalPayload.majorSystemVersion)
        print("majorSystemVersion", SignalPayload.majorSystemVersion)
    }
    
    func testMajorMinorSystemVersion() {
        XCTAssertNoThrow(SignalPayload.majorMinorSystemVersion)
        print("majorMinorSystemVersion", SignalPayload.majorMinorSystemVersion)
    }
    
    func testAppVersion() {
        XCTAssertNoThrow(SignalPayload.appVersion)
        print("appVersion", SignalPayload.appVersion)
    }
    
    func testBuildNumber() {
        XCTAssertNoThrow(SignalPayload.buildNumber)
        print("buildNumber", SignalPayload.buildNumber)
    }
    
    func testModelName() {
        XCTAssertNoThrow(SignalPayload.modelName)
        print("modelName", SignalPayload.modelName)
    }
    
    func testArchitecture() {
        XCTAssertNoThrow(SignalPayload.architecture)
        print("architecture", SignalPayload.architecture)
    }
    
    func testOperatingSystem() {
        let expectedResult: String
        
        #if os(macOS)
            expectedResult = "macOS"
        #elseif os(iOS)
            expectedResult = "iOS"
        #elseif os(watchOS)
            expectedResult = "watchOS"
        #elseif os(tvOS)
            expectedResult = "tvOS"
        #elseif os(Linux)
            expectedResult = "Linux"
        #else
            return "Unknown Operating System"
        #endif
        
        XCTAssertEqual(expectedResult, SignalPayload.operatingSystem)
        
        print("operatingSystem", SignalPayload.operatingSystem)
    }
    
    func testPlatform() {
        XCTAssertNoThrow(SignalPayload.platform)
        print("platform", SignalPayload.platform)
    }
    
    func testTargetEnvironment() {
        XCTAssertNoThrow(SignalPayload.targetEnvironment)
        print("targetEnvironment", SignalPayload.targetEnvironment)
    }
    
    func testLocale() {
        XCTAssertNoThrow(SignalPayload.locale)
        print("locale", SignalPayload.locale)
    }
}
