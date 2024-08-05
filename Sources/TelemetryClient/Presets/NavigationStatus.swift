import Foundation

/// This internal singleton keeps track of the last used navigation path so
/// that the ``TelemetryDeck.navigationPathChanged(to:customUserID:)`` function has a `from` source to work off of.
@MainActor
class NavigationStatus {
    static let shared = NavigationStatus()

    var previousNavigationPath: String?
}
