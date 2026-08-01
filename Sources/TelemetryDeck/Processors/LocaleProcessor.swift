import Foundation

/// Enriches events with the current locale, language, preferred language, and region.
public struct LocaleProcessor: EventProcessor {
    /// Creates a locale processor.
    public init() {}

    /// Adds locale, language, and region parameters to the context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context

        let locale = Locale.current
        context.addParameter(DefaultParams.RunContext.locale, value: locale.identifier)

        let appLanguage: String
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            appLanguage = locale.language.languageCode?.identifier ?? locale.identifier.components(separatedBy: .init(charactersIn: "-_"))[0]
        } else {
            appLanguage = locale.languageCode ?? locale.identifier.components(separatedBy: .init(charactersIn: "-_"))[0]
        }
        context.addParameter(DefaultParams.RunContext.language, value: appLanguage)

        let preferredLocaleIdentifier = Locale.preferredLanguages.first ?? "zz-ZZ"
        let preferredLanguage = preferredLocaleIdentifier.components(separatedBy: .init(charactersIn: "-_"))[0]
        context.addParameter(DefaultParams.UserPreference.language, value: preferredLanguage)

        let region: String
        if #available(iOS 16, macOS 13, tvOS 16, visionOS 1, watchOS 9, *) {
            region = locale.region?.identifier ?? locale.identifier.components(separatedBy: .init(charactersIn: "-_")).last!
        } else {
            region = locale.regionCode ?? locale.identifier.components(separatedBy: .init(charactersIn: "-_")).last!
        }
        context.addParameter(DefaultParams.UserPreference.region, value: region)

        return try await next(input, context)
    }
}
