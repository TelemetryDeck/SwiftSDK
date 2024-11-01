@testable import TelemetryDeck
import Testing

actor LogHandlerTests {
    var counter: Int = 0
    var lastLevel: LogHandler.LogLevel?

    @Test
    func logHandler_stdoutLogLevelDefined() {
        #expect(LogHandler.standard(.error).logLevel == .error)
    }

    @Test
    func logHandler_logLevelRespected() async throws {
        let handler = LogHandler(logLevel: .info) { _, _ in
            Task {
                await self.increment()
            }
        }
        
        #expect(counter == 0)

        handler.log(.debug, message: "")
        try await Task.sleep(for: .milliseconds(10))
        #expect(counter == 0)

        handler.log(.info, message: "")
        try await Task.sleep(for: .milliseconds(10))
        #expect(counter == 1)

        handler.log(.error, message: "")
        try await Task.sleep(for: .milliseconds(10))
        #expect(counter == 2)
    }

    @Test
    func logHandler_defaultLogLevel() async throws {
        let handler = LogHandler(logLevel: .debug) { level, _ in
            Task {
                await self.setLastLevel(level)
            }
        }
        
        handler.log(message: "")
        try await Task.sleep(for: .milliseconds(10))
        #expect(lastLevel == .info)
    }

    private func increment() {
        self.counter += 1
    }

    private func setLastLevel(_ lastLevel: LogHandler.LogLevel?) {
        self.lastLevel = lastLevel
    }
}
