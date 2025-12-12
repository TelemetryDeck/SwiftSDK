import Testing

@testable import TelemetryDeck

struct DefaultSignalPayloadTests {
    @Test
    func isSimulatorOrTestFlight() {
        print("isSimulatorOrTestFlight", DefaultSignalPayload.isSimulatorOrTestFlight)
    }

    @Test
    func isSimulator() {
        print("isSimulator", DefaultSignalPayload.isSimulator)
    }

    @Test
    func isDebug() {
        #expect(DefaultSignalPayload.isDebug == true)
        print("isDebug", DefaultSignalPayload.isDebug)
    }

    @Test
    func isTestFlight() {
        #expect(DefaultSignalPayload.isTestFlight == false)
        print("isTestFlight", DefaultSignalPayload.isTestFlight)
    }

    @Test
    func isAppStore() {
        #expect(DefaultSignalPayload.isAppStore == false)
        print("isAppStore", DefaultSignalPayload.isAppStore)
    }

    @Test
    func systemVersion() {
        print("systemVersion", DefaultSignalPayload.systemVersion)
    }

    @Test
    func majorSystemVersion() {
        print("majorSystemVersion", DefaultSignalPayload.majorSystemVersion)
    }

    @Test
    func majorMinorSystemVersion() {
        print("majorMinorSystemVersion", DefaultSignalPayload.majorMinorSystemVersion)
    }

    @Test
    func appVersion() {
        print("appVersion", DefaultSignalPayload.appVersion)
    }

    @Test
    func buildNumber() {
        print("buildNumber", DefaultSignalPayload.buildNumber)
    }

    @Test
    func modelName() {
        print("modelName", DefaultSignalPayload.modelName)
    }

    @Test
    func architecture() {
        print("architecture", DefaultSignalPayload.architecture)
    }

    @Test
    func operatingSystem() {
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
        #elseif os(visionOS)
            expectedResult = "visionOS"
        #else
            return "Unknown Operating System"
        #endif

        #expect(expectedResult == DefaultSignalPayload.operatingSystem)

        print("operatingSystem", DefaultSignalPayload.operatingSystem)
    }

    @Test
    func platform() {
        print("platform", DefaultSignalPayload.platform)
    }

    @Test
    func targetEnvironment() {
        print("targetEnvironment", DefaultSignalPayload.targetEnvironment)
    }

    @Test
    func locale() {
        print("locale", DefaultSignalPayload.locale)
    }
}
