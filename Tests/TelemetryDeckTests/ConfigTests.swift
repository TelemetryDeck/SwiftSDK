import Foundation
import Testing

@testable import TelemetryDeck

struct ConfigTests {
    @Test
    func defaultValues() {
        let config = TelemetryDeck.Config(
            appID: "test-app-id",
            namespace: "test-namespace"
        )

        #expect(config.appID == "test-app-id")
        #expect(config.namespace == "test-namespace")
        #expect(config.apiBaseURL == URL(string: "https://nom.telemetrydeck.com")!)
        #expect(config.salt == "")
    }

    @Test
    func customAPIBaseURL() {
        let customURL = URL(string: "https://custom.telemetry.example.com")!
        let config = TelemetryDeck.Config(
            appID: "test-app-id",
            namespace: "test-namespace",
            apiBaseURL: customURL
        )

        #expect(config.apiBaseURL == customURL)
    }

    @Test
    func customSalt() {
        let customSalt = "my-custom-salt-12345"
        let config = TelemetryDeck.Config(
            appID: "test-app-id",
            namespace: "test-namespace",
            salt: customSalt
        )

        #expect(config.salt == customSalt)
    }

    // MARK: - Validation

    @Test
    func validateThrowsForEmptyAppID() {
        let config = TelemetryDeck.Config(appID: "", namespace: "test-namespace")
        #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
    }

    @Test
    func validateThrowsForWhitespaceOnlyAppID() {
        let config = TelemetryDeck.Config(appID: "   \t\n", namespace: "test-namespace")
        #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
    }

    @Test
    func validateThrowsForEmptyNamespace() {
        let config = TelemetryDeck.Config(appID: "valid-app-id", namespace: "")
        #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
    }

    @Test
    func validateThrowsForWhitespaceOnlyNamespace() {
        let config = TelemetryDeck.Config(appID: "valid-app-id", namespace: "   ")
        #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
    }

    @Test(arguments: ["my namespace", "a/b", "ns?x", "names:pace", "über"])
    func validateThrowsForNamespaceWithCharactersTheServerRejects(namespace: String) {
        let config = TelemetryDeck.Config(appID: "valid-app-id", namespace: namespace)
        #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
    }

    @Test(arguments: ["valid-namespace", "Valid.Name_1-2", "W", "w.example", "com.w"])
    func validateSucceedsForValidConfig(namespace: String) throws {
        let config = TelemetryDeck.Config(appID: "valid-app-id", namespace: namespace)
        try config.validate()
    }

    @Test
    func validateThrowsForReservedNamespace() {
        let config = TelemetryDeck.Config(appID: "valid-app-id", namespace: "w")
        let error = #expect(throws: TelemetryDeckError.self) {
            try config.validate()
        }
        #expect(error?.code == .invalidConfiguration)
    }

    @Test
    func validateErrorCodeIsInvalidConfig() {
        let config = TelemetryDeck.Config(appID: "", namespace: "test")
        do {
            try config.validate()
            Issue.record("Expected TelemetryDeckError to be thrown")
        } catch {
            #expect(error.code == .invalidConfiguration)
        }
    }
}
