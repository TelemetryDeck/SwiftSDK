import Foundation

extension TelemetryDeck {
    /// Configuration for the TelemetryDeck SDK, specifying the app identity and transport settings.
    public struct Config: Sendable {
        /// The TelemetryDeck app identifier from the dashboard.
        public let appID: String
        /// The server-side namespace used for API routing (appears in the ingestion URL path).
        public let namespace: String
        /// The base URL of the TelemetryDeck ingestion API.
        public let apiBaseURL: URL
        /// A salt value appended to user identifiers before hashing for additional privacy.
        public let salt: String

        /// Creates a configuration with the given app identity and optional transport overrides.
        public init(
            appID: String,
            namespace: String,
            apiBaseURL: URL = URL(string: "https://nom.telemetrydeck.com")!,
            salt: String = ""
        ) {
            self.appID = appID
            self.namespace = namespace
            self.apiBaseURL = apiBaseURL
            self.salt = salt
        }

        func validate() throws(TelemetryDeckError) {
            guard !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TelemetryDeckError(
                    code: .invalidConfiguration,
                    localizedDescription: "appID must not be empty. Get your app ID from the TelemetryDeck dashboard."
                )
            }

            guard !namespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TelemetryDeckError(
                    code: .invalidConfiguration,
                    localizedDescription: "namespace must not be empty."
                )
            }
        }
    }
}
