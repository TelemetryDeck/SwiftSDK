import Foundation

/// Injectable source of time.
///
/// Allows for platform-specific implementation of getting the current date and time.
/// Can be injected during testing to make time-bearing logic deterministic.
struct DateProvider: Sendable {
    /// Returns the current date and time.
    let now: @Sendable () -> Date

    /// Creates a date provider backed by the given closure.
    init(now: @Sendable @escaping () -> Date) {
        self.now = now
    }

    /// The system clock provider, returning `Date()` on each call.
    static let system = DateProvider(now: { Date() })
}
