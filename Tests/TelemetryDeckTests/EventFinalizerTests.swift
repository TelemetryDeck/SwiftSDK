import Testing

@testable import TelemetryDeck

struct EventFinalizerTests {
    @Test
    func saltIsUsedInHashing() {
        let configWithSalt1 = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns", salt: "salt1")
        let configWithSalt2 = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns", salt: "salt2")

        let finalizer1 = EventFinalizer(configuration: configWithSalt1)
        let finalizer2 = EventFinalizer(configuration: configWithSalt2)

        var context = EventContext()
        context.userIdentifier = "user@example.com"

        let input = EventInput("Test.signal")

        let signal1 = finalizer1.finalize(input, context: context)
        let signal2 = finalizer2.finalize(input, context: context)

        #expect(signal1.clientUser != signal2.clientUser)
    }

    @Test
    func nilUserIdentifierFallsBackToDefault() {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")
        let finalizer = EventFinalizer(configuration: config)

        var context = EventContext()
        context.userIdentifier = nil

        let input = EventInput("Test.signal")
        let signal = finalizer.finalize(input, context: context)

        let expectedHash = CryptoHashing.sha256(string: "unknown user", salt: "")
        #expect(signal.clientUser == expectedHash)
        #expect(!signal.clientUser.isEmpty)
    }

    @Test
    func nilIsTestModeDefaultsToFalse() {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")
        let finalizer = EventFinalizer(configuration: config)

        var context = EventContext()
        context.isTestMode = nil

        let input = EventInput("Test.signal")
        let signal = finalizer.finalize(input, context: context)

        #expect(signal.isTestMode == "false")
    }

    @Test
    func sessionIDIsNilWhenContextHasNoSession() {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")
        let finalizer = EventFinalizer(configuration: config)

        var context = EventContext()
        context.sessionID = nil

        let input = EventInput("Test.signal")
        let signal = finalizer.finalize(input, context: context)

        #expect(signal.sessionID == nil)
    }

    @Test
    func inputParametersOverrideContextParameters() {
        let config = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")
        let finalizer = EventFinalizer(configuration: config)

        var context = EventContext()
        context.addParameter("key", value: "A")

        let input = EventInput("Test.signal", parameters: ["key": "B"])
        let signal = finalizer.finalize(input, context: context)

        #expect(signal.payload["key"] == "B")
    }
}
