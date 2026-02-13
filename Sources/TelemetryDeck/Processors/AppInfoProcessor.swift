import Foundation

let sdkVersion = "3.0.0"

/// Enriches events with app version, build number, and SDK version metadata.
public struct AppInfoProcessor: EventProcessor {
    private let cachedParameters: EventParameters

    /// Creates a processor and caches app and SDK version information from the main bundle.
    public init() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

        var params: EventParameters = [
            DefaultParams.AppInfo.version.rawValue: appVersion,
            DefaultParams.AppInfo.buildNumber.rawValue: buildNumber,
            DefaultParams.AppInfo.versionAndBuildNumber.rawValue: "\(appVersion) (build \(buildNumber))",
            DefaultParams.SDK.name.rawValue: "SwiftSDK",
            DefaultParams.SDK.version.rawValue: sdkVersion,
            DefaultParams.SDK.nameAndVersion.rawValue: "SwiftSDK \(sdkVersion)",
        ]

        if let container = Bundle.main.infoDictionary?["NSExtension"] as? [String: Any],
            let extensionID = container["NSExtensionPointIdentifier"] as? String
        {
            params[DefaultParams.RunContext.extensionIdentifier] = extensionID
        }

        self.cachedParameters = params
    }

    /// Adds cached app and SDK version parameters to the context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.addParameters(cachedParameters)
        return try await next(input, context)
    }
}
