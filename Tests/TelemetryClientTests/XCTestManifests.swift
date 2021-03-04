import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(TelemetryClientTests.allTests),
        ]
    }
#endif
