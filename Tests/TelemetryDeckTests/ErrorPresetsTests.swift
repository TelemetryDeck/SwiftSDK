import Foundation
import Testing

@testable import TelemetryDeck

struct ErrorPresetsTests {
    @Test
    func errorCategoryRawValues() {
        #expect(ErrorCategory.thrownException.rawValue == "thrown-exception")
        #expect(ErrorCategory.userInput.rawValue == "user-input")
        #expect(ErrorCategory.appState.rawValue == "app-state")
    }

    @Test
    func anyIdentifiableErrorWrapsError() {
        let originalError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let wrappedError = AnyIdentifiableError(id: "test-id", error: originalError)

        #expect(wrappedError.id == "test-id")
        #expect(wrappedError.errorDescription == "Test error")
    }

    @Test
    func errorWithIdCreatesWrapper() {
        let originalError = NSError(domain: "test", code: 123)
        let identifiableError = originalError.with(id: "error-123")

        #expect(identifiableError.id == "error-123")
        #expect((identifiableError.error as NSError).code == originalError.code)
    }

    @Test
    func identifiableErrorConformsToLocalizedError() {
        let originalError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Localized"])
        let wrappedError = AnyIdentifiableError(id: "test", error: originalError)

        #expect(wrappedError.errorDescription == "Localized")
    }

    @Test
    func identifiableErrorWithNonLocalizedError() {
        struct SimpleError: Error {}
        let error = SimpleError()
        let wrapped = AnyIdentifiableError(id: "simple", error: error)

        #expect(wrapped.id == "simple")
    }
}
