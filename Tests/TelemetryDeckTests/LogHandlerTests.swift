@testable import TelemetryDeck
import XCTest

final class LogHandlerTests: XCTestCase {
    var counter: Int = 0
    var lastLevel: LogHandler.LogLevel?

    func testLogHandler_stdoutLogLevelDefined() {
        XCTAssertEqual(LogHandler.stdout(.error).logLevel, .error)
    }
    
    func testLogHandler_logLevelRespected() {
        let handler = LogHandler(logLevel: .info) { _, _ in
            self.counter += 1
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
        let handler = LogHandler(logLevel: .debug) { level, _ in
            self.lastLevel = level
        }
        
        handler.log(message: "")
        XCTAssertEqual(lastLevel, .info)
    }
}
