@testable import TelemetryClient
import XCTest

final class DefaultSignalPayloadTests: XCTestCase {
    func testIsSimulatorOrTestFlight() {
        XCTAssertNoThrow(DefaultSignalPayload.isSimulatorOrTestFlight)
        print("isSimulatorOrTestFlight", DefaultSignalPayload.isSimulatorOrTestFlight)
    }
    
    func testIsSimulator() {
        XCTAssertNoThrow(DefaultSignalPayload.isSimulator)
        print("isSimulator", DefaultSignalPayload.isSimulator)
    }
    
    func testIsDebug() {
        XCTAssertTrue(DefaultSignalPayload.isDebug)
        print("isDebug", DefaultSignalPayload.isDebug)
    }
    
    func testIsTestFlight() {
        XCTAssertFalse(DefaultSignalPayload.isTestFlight)
        print("isTestFlight", DefaultSignalPayload.isTestFlight)
    }
    
    func testIsAppStore() {
        XCTAssertFalse(DefaultSignalPayload.isAppStore)
        print("isAppStore", DefaultSignalPayload.isAppStore)
    }
    
    func testSystemVersion() {
        XCTAssertNoThrow(DefaultSignalPayload.systemVersion)
        print("systemVersion", DefaultSignalPayload.systemVersion)
    }
    
    func testMajorSystemVersion() {
        XCTAssertNoThrow(DefaultSignalPayload.majorSystemVersion)
        print("majorSystemVersion", DefaultSignalPayload.majorSystemVersion)
    }
    
    func testMajorMinorSystemVersion() {
        XCTAssertNoThrow(DefaultSignalPayload.majorMinorSystemVersion)
        print("majorMinorSystemVersion", DefaultSignalPayload.majorMinorSystemVersion)
    }
    
    func testAppVersion() {
        XCTAssertNoThrow(DefaultSignalPayload.appVersion)
        print("appVersion", DefaultSignalPayload.appVersion)
    }
    
    func testBuildNumber() {
        XCTAssertNoThrow(DefaultSignalPayload.buildNumber)
        print("buildNumber", DefaultSignalPayload.buildNumber)
    }
    
    func testModelName() {
        XCTAssertNoThrow(DefaultSignalPayload.modelName)
        print("modelName", DefaultSignalPayload.modelName)
    }
    
    func testArchitecture() {
        XCTAssertNoThrow(DefaultSignalPayload.architecture)
        print("architecture", DefaultSignalPayload.architecture)
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
        
        XCTAssertEqual(expectedResult, DefaultSignalPayload.operatingSystem)
        
        print("operatingSystem", DefaultSignalPayload.operatingSystem)
    }
    
    func testPlatform() {
        XCTAssertNoThrow(DefaultSignalPayload.platform)
        print("platform", DefaultSignalPayload.platform)
    }
    
    func testTargetEnvironment() {
        XCTAssertNoThrow(DefaultSignalPayload.targetEnvironment)
        print("targetEnvironment", DefaultSignalPayload.targetEnvironment)
    }
    
    func testLocale() {
        XCTAssertNoThrow(DefaultSignalPayload.locale)
        print("locale", DefaultSignalPayload.locale)
    }
}
