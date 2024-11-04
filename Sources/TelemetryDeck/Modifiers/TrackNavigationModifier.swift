#if canImport(SwiftUI)
import SwiftUI

/// A view modifier that automatically sends navigation signals to TelemetryDeck when a view appears.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
private struct TrackNavigationModifier: ViewModifier {
    let path: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                TelemetryDeck.navigationPathChanged(to: path)
            }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension View {
    /// Tracks navigation to this view by sending a signal to TelemetryDeck when the view appears.
    ///
    /// Use this modifier to automatically track user navigation through your app. The modifier will send
    /// a navigation signal to TelemetryDeck whenever the view appears, using the provided path.
    ///
    /// Navigation paths should be delineated by either `.` or `/` characters to represent hierarchy.
    /// Keep paths generic and avoid including dynamic values like IDs to ensure meaningful analytics.
    ///
    /// For example:
    /// - `settings.profile`
    /// - `store.items.detail`
    /// - `onboarding.step2`
    ///
    /// # Example Usage
    /// ```swift
    /// struct AppTabView: View {
    ///     var body: some View {
    ///         TabView {
    ///             HomeView()
    ///                 .trackNavigation(path: "home")
    ///                 .tabItem { Text("Home") }
    ///
    ///             StoreView()
    ///                 .trackNavigation(path: "store.browse")
    ///                 .tabItem { Text("Store") }
    ///
    ///             ProfileView()
    ///                 .trackNavigation(path: "profile")
    ///                 .tabItem { Text("Profile") }
    ///         }
    ///     }
    /// }
    ///
    /// struct StoreItemView: View {
    ///     let itemId: String
    ///
    ///     var body: some View {
    ///         ItemDetailsView()
    ///             .trackNavigation(path: "store.items.detail")
    ///     }
    /// }
    ///
    /// struct SettingsView: View {
    ///     var body: some View {
    ///         Form {
    ///             NavigationLink("Account") {
    ///                 AccountSettingsView()
    ///                     .trackNavigation(path: "settings.account")
    ///             }
    ///             NavigationLink("Privacy") {
    ///                 PrivacySettingsView()
    ///                     .trackNavigation(path: "settings.privacy")
    ///             }
    ///         }
    ///         .trackNavigation(path: "settings")
    ///     }
    /// }
    /// ```
    ///
    /// - Note: For accurate navigation tracking, ensure you consistently apply this modifier to all views
    ///         that represent navigation destinations in your app. Otherwise, TelemetryDeck might record
    ///         incorrect navigation paths since it uses the previously recorded destination as the source
    ///         for the next navigation event.
    ///
    /// - Parameter path: The navigation path that identifies this view in your analytics.
    ///                   Use dot notation (e.g., "settings.account") to represent hierarchy.
    /// - Returns: A view that triggers navigation tracking when it appears.
    public func trackNavigation(path: String) -> some View {
        modifier(TrackNavigationModifier(path: path))
    }
}
#endif
