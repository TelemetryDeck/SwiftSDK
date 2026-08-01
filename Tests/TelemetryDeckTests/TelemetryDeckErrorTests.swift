import Foundation
import Testing

@testable import TelemetryDeck

struct TelemetryDeckErrorTests {
    @Test
    func invalidConfigurationCodeRawValue() {
        #expect(TelemetryDeckError.Code.invalidConfiguration.rawValue == 1001)
    }

    @Test
    func errorDomainIsTelemetryDeck() {
        let error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: "test")
        #expect(TelemetryDeckError.errorDomain == "TelemetryDeck")
        #expect((error as NSError).domain == "TelemetryDeck")
    }

    @Test
    func nsErrorCodeMatchesRawValue() {
        let error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: "test")
        let nsError = error as NSError
        #expect(nsError.code == 1001)
    }

    @Test
    func nsErrorUserInfoContainsLocalizedDescription() {
        let message = "appID must not be empty"
        let error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: message)
        let nsError = error as NSError
        #expect(nsError.localizedDescription == message)
    }

    @Test
    func localizedErrorDescriptionMatchesMessage() {
        let message = "Something went wrong"
        let error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: message)
        #expect(error.errorDescription == message)
    }

    @Test
    func debugDescriptionIncludesCodeAndMessage() {
        let error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: "bad config")
        #expect(error.debugDescription == "TelemetryDeckError.invalidConfiguration (1001): bad config")
    }

    @Test
    func patternMatchingOnCodeSucceeds() {
        let error: any Error = TelemetryDeckError(code: .invalidConfiguration, localizedDescription: "test")
        #expect(TelemetryDeckError.Code.invalidConfiguration ~= error)
    }

    @Test
    func patternMatchingOnUnrelatedErrorFails() {
        let error: any Error = URLError(.badURL)
        #expect(!(TelemetryDeckError.Code.invalidConfiguration ~= error))
    }

    @Test
    func typedCatchAllowsDirectCodeAccess() {
        let config = TelemetryDeck.Config(appID: "", namespace: "test")
        do {
            try config.validate()
            Issue.record("Expected TelemetryDeckError to be thrown")
        } catch {
            #expect(error.code == .invalidConfiguration)
        }
    }
}
