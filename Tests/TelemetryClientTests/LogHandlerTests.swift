@testable import TelemetryClient
import XCTest

final class LogHandlerTests: XCTestCase {
    func testLogHandler_stdoutLogLevelDefined() {
        XCTAssertEqual(LogHandler.stdout(.error).logLevel, .error)
    }
    
    func testLogHandler_logLevelRespected() {
        var counter = 0
        
        let handler = LogHandler(logLevel: .info) { _, _ in
            counter += 1
        }
        
        XCTAssertEqual(counter, 0)
        handler.log(.debug, message: "")
        XCTAssertEqual(counter, 0)
        handler.log(.info, message: "")
        XCTAssertEqual(counter, 1)
        handler.log(.error, message: "")
        XCTAssertEqual(counter, 2)
    }
    
    func testLogHandler_defaultLogLevel() {
        var lastLevel: LogHandler.LogLevel?
        
        let handler = LogHandler(logLevel: .debug) { level, _ in
            lastLevel = level
        }
        
        handler.log(message: "")
        XCTAssertEqual(lastLevel, .info)
    }
}
