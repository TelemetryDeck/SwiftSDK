import Foundation

/// An enumeration of common categories for errors. Each case has its own insight preset on TelemetryDeck.
public enum ErrorCategory: String {
    /// Represents an error that was thrown as an exception.
    case thrownException = "thrown-exception"

    /// Represents an error caused by user input.
    case userInput = "user-input"

    /// Represents an error caused by the application's state.
    case appState = "app-state"
}
