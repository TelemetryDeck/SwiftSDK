# TelemetryDeck SwiftSDK

Privacy-first analytics for Apple platforms. Send events to [TelemetryDeck](https://telemetrydeck.com) from your Swift code.

## Requirements

- iOS 15+ / macOS 12+ / watchOS 8+ / tvOS 15+ / visionOS 1+
- Swift 6.2+ / Xcode 26+
- Swift Package Manager (CocoaPods is not supported)

## Installation

In Xcode, press _File > Add Packages..._, then enter `https://github.com/TelemetryDeck/SwiftSDK` into the search field. Set the _Dependency Rule_ field to _Up to Next Major Version_, then press _Add Package_. Add the "TelemetryDeck" library to your app target.

See our [detailed setup guide](https://telemetrydeck.com/docs/guides/swift-setup/?source=github) for more information.

## Quick Start

Initialize TelemetryDeck at app startup with your App ID and namespace (both available in your [TelemetryDeck Dashboard](https://dashboard.telemetrydeck.com/) under Set Up App):

```swift
import SwiftUI
import TelemetryDeck

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        // Do not put this in WindowGroup.onAppear — it would run too late.
        let config = TelemetryDeck.Config(
            appID: "<YOUR-APP-ID>",
            namespace: "<YOUR-NAMESPACE>"
        )
        Task { try await TelemetryDeck.initialize(configuration: config) }
    }
}
```

Then send events anywhere in your app:

```swift
TelemetryDeck.event("App.launchedRegularly")
```

That's it. TelemetryDeck automatically enriches every event with device info, OS version, app version, accessibility settings, and more.

## Sending Events

`event()` works in both sync and async contexts — the compiler picks the right variant automatically:

```swift
TelemetryDeck.event("Settings.opened")          // fire-and-forget
await TelemetryDeck.event("Settings.opened")    // awaitable
```

`event()` accepts `RawRepresentable<String>` so you could also keep track of your event types using an enumeration:

```swift
enum AppEvent: String {
    case launched = "App.launched"
    case settingsOpened = "Settings.opened"
}

TelemetryDeck.event(AppEvent.launched)
```

### Parameters

Send additional metadata with each event using typed `EventParameters`. Values can be `String`, `Bool`, `Int`, `Double`, `Float`, `UUID`, or `Date`:

```swift
TelemetryDeck.event("Database.updated", parameters: [
    "entryCount": 3831,
    "isCompacted": true
])
```

### Float Values

Attach a numeric measurement to any event:

```swift
TelemetryDeck.event("Upload.completed", floatValue: fileSize)
```

<details>
<summary>TelemetryDeck automatically sends base parameters with every event (expand to see common examples)</summary>

- TelemetryDeck.Accessibility.isBoldTextEnabled
- TelemetryDeck.Accessibility.preferredContentSizeCategory
- TelemetryDeck.AppInfo.buildNumber
- TelemetryDeck.AppInfo.version
- TelemetryDeck.Device.architecture
- TelemetryDeck.Device.modelName
- TelemetryDeck.Device.operatingSystem
- TelemetryDeck.Device.orientation
- TelemetryDeck.Device.platform
- TelemetryDeck.Device.screenResolutionHeight
- TelemetryDeck.Device.screenResolutionWidth
- TelemetryDeck.Device.systemMajorMinorVersion
- TelemetryDeck.Device.systemMajorVersion
- TelemetryDeck.Device.systemVersion
- TelemetryDeck.Device.timeZone
- TelemetryDeck.RunContext.isAppStore
- TelemetryDeck.RunContext.isDebug
- TelemetryDeck.RunContext.isSimulator
- TelemetryDeck.RunContext.isTestFlight
- TelemetryDeck.RunContext.language
- TelemetryDeck.RunContext.targetEnvironment
- TelemetryDeck.SDK.version
- TelemetryDeck.UserPreference.colorScheme
- TelemetryDeck.UserPreference.language
- TelemetryDeck.UserPreference.layoutDirection
- TelemetryDeck.UserPreference.region

See our [related documentation page](https://telemetrydeck.com/docs/api/default-parameters/?source=github.com) for a full list.
</details>

## User Identifiers

TelemetryDeck generates a per-installation user identifier by default. If you have a better identifier (e.g. email or username), set it at any time — it will be hashed before transmission:

```swift
await TelemetryDeck.setUserIdentifier("myuser@example.com")
```

Pass `nil` to revert to the default identifier.

## Sessions

A session ID is automatically generated at initialization. On iOS, tvOS, and watchOS, the session updates whenever your app returns from the background. On other platforms, a new session starts each time the app launches.

For manual session control:

```swift
await TelemetryDeck.newSession()
```

## Test Mode

In debug builds, all events are automatically marked as test events. View them in the TelemetryDeck dashboard by enabling **Test Mode**.

## Disabling Analytics

Let users opt out of analytics collection:

```swift
await TelemetryDeck.setAnalyticsDisabled(true)
```

While disabled, all events are silently dropped. Check the current state with `await TelemetryDeck.isAnalyticsDisabled`.

## Shutting Down

To flush pending events and shut down the SDK:

```swift
await TelemetryDeck.terminate()
```

<details>
<summary>Configuration Reference</summary>

**`TelemetryDeck.Config`**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `appID` | `String` | (required) | Your app ID from the dashboard |
| `namespace` | `String` | (required) | Your namespace from the dashboard |
| `apiBaseURL` | `URL` | `https://nom.telemetrydeck.com` | Ingestion server URL |
| `salt` | `String` | `""` | Client-side salt for user ID hashing |

**`TelemetryDeck.initialize()` parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `defaultUser` | `String?` | `nil` | Initial user identifier (hashed before transmission) |
| `testMode` | `Bool?` | `nil` | Force test mode on/off; `nil` auto-detects from build configuration |
| `eventPrefix` | `String?` | `nil` | Auto-prefix for all event names |
| `parameterPrefix` | `String?` | `nil` | Auto-prefix for all parameter keys |
| `sendSessionStartedEvent` | `Bool` | `true` | Send an event when a new session begins |
| `defaultParameters` | `EventParameters` | `[:]` | Parameters merged into every event |

</details>

## Presets

### Navigation Tracking

Track screen views with the SwiftUI view modifier:

```swift
ContentView()
    .trackNavigation(path: "Home")
```

Or call it manually:

```swift
await TelemetryDeck.navigationPathChanged(from: "Home", to: "Settings")
```

### Error Reporting

```swift
await TelemetryDeck.errorOccurred(
    id: "database-write-failure",
    category: .thrownException,
    message: error.localizedDescription
)
```

Use the `.with(id:)` extension to tag any `Error` with a stable identifier:

```swift
catch {
    await TelemetryDeck.errorOccurred(identifiableError: error.with(id: "sync-failed"))
}
```

### Duration Tracking

Measure time spent on activities:

```swift
await TelemetryDeck.startDurationEvent("Editor.session")
// ... user works ...
await TelemetryDeck.stopAndSendDurationEvent("Editor.session")
```

Use `includeBackgroundTime: false` (the default) to only count foreground time. Cancel without sending via `cancelDurationEvent(_:)`.

### Purchase Tracking

Track StoreKit transactions:

```swift
await TelemetryDeck.purchaseCompleted(transaction: transaction)
```

Free trials are automatically detected and reported separately. Please note that we do not keep track of transactions - repeatedly calling this method will result in multiple events.

### Pirate Metrics (AARRR)

Track the full acquisition-to-revenue funnel:

```swift
await TelemetryDeck.acquiredUser(channel: "organic-search")
await TelemetryDeck.onboardingCompleted()
await TelemetryDeck.coreFeatureUsed(featureName: "export")
await TelemetryDeck.referralSent(receiversCount: 3)
await TelemetryDeck.paywallShown(reason: "feature-gate")
```

## Advanced

### Custom Salt

For additional privacy, add your own salt to user identifier hashing:

```swift
let config = TelemetryDeck.Config(
    appID: "<YOUR-APP-ID>",
    namespace: "<YOUR-NAMESPACE>",
    salt: "<A RANDOM STRING>"
)
```

### Custom Server

Use a custom ingestion server or proxy:

```swift
let config = TelemetryDeck.Config(
    appID: "<YOUR-APP-ID>",
    namespace: "<YOUR-NAMESPACE>",
    apiBaseURL: URL(string: "https://custom.example.com")!
)
```

### Custom Event Transmitter

For fine-grained control over networking (e.g. certificate pinning or a custom proxy), create your own `DefaultEventTransmitter`:

```swift
let config = TelemetryDeck.Config(appID: "<YOUR-APP-ID>", namespace: "<YOUR-NAMESPACE>")
let cache = DefaultEventCache()
let transmitter = DefaultEventTransmitter(
    configuration: config,
    cache: cache,
    logger: DefaultLogger(),
    urlSession: myCustomURLSession
)
try await TelemetryDeck.initialize(
    configuration: config,
    processors: TelemetryDeck.defaultProcessors(),
    cache: cache,
    transmitter: transmitter
)
```

### Cache configuration

`DefaultEventCache` and `DefaultEventTransmitter` expose parameters to control how the SDK will retry sending events in case of a problem:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DefaultEventCache(cacheLimit:)` | `Int` | `10_000` | Maximum events held in memory; oldest events are dropped first when the limit is reached |
| `DefaultEventTransmitter(transmitInterval:)` | `TimeInterval` | `10` | Seconds between transmission attempts |
| `DefaultEventTransmitter(maxBackoffInterval:)` | `TimeInterval` | `300` | Upper bound for exponential backoff after consecutive failed batches |

```swift
let cache = DefaultEventCache(cacheLimit: 5_000)
let transmitter = DefaultEventTransmitter(
    configuration: config,
    cache: cache,
    logger: DefaultLogger(),
    transmitInterval: 30,
    maxBackoffInterval: 600
)
```

You can also implement the `EventTransmitting` protocol for a fully custom transport layer.

### Custom Logging

Provide a custom logger conforming to the `Logging` protocol:

```swift
try await TelemetryDeck.initialize(
    configuration: config,
    processors: TelemetryDeck.defaultProcessors(),
    logger: myCustomLogger
)
```

### Default Event Processors

Events pass through a pipeline of `EventProcessor` middleware before transmission. The SDK ships with these default processors, executed in order:

| # | Processor | Purpose |
|---|-----------|---------|
| 1 | `PreviewFilterProcessor` | Drops events during SwiftUI previews |
| 2 | `DefaultParametersProcessor` | Merges `defaultParameters` into every event |
| 3 | `DefaultPrefixProcessor` | Applies `eventPrefix` and `parameterPrefix` |
| 4 | `ValidationProcessor` | Warns when event names or parameter keys use reserved `TelemetryDeck.*` identifiers |
| 5 | `TestModeProcessor` | Marks events as test events in debug builds (override with `TestModeProcessor(override: true/false)`) |
| 6 | `UserIdentifierProcessor` | Resolves and attaches the hashed user identifier |
| 7 | `SessionTrackingProcessor` | Manages session IDs, retention metrics, and new-install detection |
| 8 | `DeviceProcessor` | Adds device model, OS version, platform, timezone, simulator/TestFlight/App Store flags |
| 9 | `AppInfoProcessor` | Adds app version, build number, and SDK version |
| 10 | `LocaleProcessor` | Adds locale, language, and region |
| 11 | `CalendarProcessor` | Adds calendar context (day of week, hour, month, quarter, etc.) |
| 12 | `AccessibilityProcessor` | Adds accessibility settings (bold text, reduce motion, etc.) and screen metrics |
| 13 | `TrialConversionProcessor` | Detects free trial → paid subscription conversions via StoreKit |

To exclude a specific processor, remove it from the default list before initializing:

```swift
var processors = TelemetryDeck.defaultProcessors()
processors.removeAll { $0 is AccessibilityProcessor }
try await TelemetryDeck.initialize(configuration: config, processors: processors)
```

You can also build a processor list from scratch for full control over which processors run.

### Custom Event Processors

Add your own processors to enrich, filter, or transform events:

```swift
struct MyProcessor: EventProcessor {
    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var ctx = context
        ctx.addMetadata(key: "MyApp.subscriptionTier", value: "premium")
        return try await next(input, ctx)
    }
}
```

Pass a custom processor list at initialization:

```swift
var processors = TelemetryDeck.defaultProcessors()
processors.append(MyProcessor())
try await TelemetryDeck.initialize(configuration: config, processors: processors)
```

If you need parameters that are computed at runtime (e.g. values that depend on current app state), use a processor instead of `defaultParameters`:

```swift
struct DynamicParametersProcessor: EventProcessor {
    func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var ctx = context
        ctx.addMetadata(key: "MyApp.itemCount", value: String(ItemStore.shared.count))
        return try await next(input, ctx)
    }
}
```

### Default Parameters and Prefixes

Attach parameters to every event, or auto-prefix all event names and parameter keys via the convenience initializer:

```swift
try await TelemetryDeck.initialize(
    appID: "<YOUR-APP-ID>",
    namespace: "<YOUR-NAMESPACE>",
    eventPrefix: "MyApp.",
    parameterPrefix: "MyApp.",
    defaultParameters: ["environment": "production"]
)
```

## Migrating from v2

### Breaking Changes

| v2 | v3 | Notes |
|----|-----|-------|
| `TelemetryDeck.initialize(config:)` | `try await TelemetryDeck.initialize(configuration:)` | Now async throws |
| `TelemetryDeck.Config(appID:)` | `TelemetryDeck.Config(appID:, namespace:)` | `namespace` is now required |
| `TelemetryManagerConfiguration` | `TelemetryDeck.Config` | Type renamed |
| `config.defaultUser = "..."` | `await TelemetryDeck.setUserIdentifier("...")` | No longer on config |
| `config.testMode` | Removed | Now handled by `TestModeProcessor`. Automatic in debug builds; override with `TestModeProcessor(override: true)` |
| `config.logHandler` | Pass `logger:` to `initialize()` | `Logging` protocol |
| `config.urlSession` | Pass custom `EventTransmitting` | See Custom Event Transmitter |
| `config.sessionID = UUID()` | `await TelemetryDeck.newSession()` | |
| `config.defaultSignalPrefix` | `eventPrefix` parameter on `initialize()` | Moved from config to initializer |
| `config.defaultParameterPrefix` | `parameterPrefix` parameter on `initialize()` | Moved from config to initializer |
| `config.sendNewSessionBeganSignal` | `sendSessionStartedEvent` parameter on `initialize()` | Moved from config to initializer |
| `config.defaultParameters` (closure) | `defaultParameters` parameter on `initialize()` | Now `EventParameters`, not `() -> [String: String]` |
| `[String: String]` parameters | `EventParameters` | Typed values: `String`, `Bool`, `Int`, `Double`, etc. |
| `TelemetryManager.shared` | Removed | Use `TelemetryDeck.*` static API |
| `requestImmediateSync()` | `await TelemetryDeck.flush()` | |
| `generateNewSession()` | `await TelemetryDeck.newSession()` | Now returns `UUID?` |
| `updateDefaultUserID(to:)` | `await TelemetryDeck.setUserIdentifier(_:)` | |
| `metadataEnrichers` / `SignalEnricher` | `EventProcessor` protocol | See Default Event Processors |
| `sendSignalsInDebugConfiguration` | Removed | Was already deprecated |
| CocoaPods | Removed | SPM only |
| `TelemetryClient` ObjC target | Removed | |
| iOS 12 / macOS 10.13 / watchOS 5 / tvOS 13 | iOS 15 / macOS 12 / watchOS 8 / tvOS 15 | Platform minimums raised |

### Before and After

**v2:**

```swift
let config = TelemetryDeck.Config(appID: "<APP-ID>")
config.defaultUser = "user@example.com"
TelemetryDeck.initialize(config: config)

TelemetryDeck.signal("App.launched")
```

**v3:**

```swift
let config = TelemetryDeck.Config(appID: "<APP-ID>", namespace: "<NAMESPACE>")
Task {
    try await TelemetryDeck.initialize(configuration: config)
    await TelemetryDeck.setUserIdentifier("user@example.com")
}

TelemetryDeck.event("App.launched")
```

### Step-by-Step Migration

1. Update your minimum deployment targets to iOS 15 / macOS 12 / watchOS 8 / tvOS 15
2. Switch to Swift Package Manager if you were using CocoaPods
3. Add `namespace:` to your `Config` initializer (get it from the dashboard under Set Up App)
4. Wrap `initialize()` in `Task { try await ... }`
5. Move `config.defaultUser` to `await TelemetryDeck.setUserIdentifier(...)`
6. Remove `config.testMode` — test mode is now automatic in debug builds via `TestModeProcessor`. To force test mode on/off, replace it in the processor list with `TestModeProcessor(override: true/false)`
7. Move `config.defaultSignalPrefix` and `config.defaultParameterPrefix` to `eventPrefix:` and `parameterPrefix:` parameters on `initialize()`
8. Move `config.sendNewSessionBeganSignal` to `sendSessionStartedEvent:` parameter on `initialize()`
9. Replace `requestImmediateSync()` with `await TelemetryDeck.flush()`
10. Replace any `TelemetryManager.shared` usage with `TelemetryDeck.*` static methods
11. If using custom `SignalEnricher`s, migrate to the `EventProcessor` protocol (see Custom Event Processors)
12. If your `defaultParameters` closure computed values at runtime, migrate to a custom `EventProcessor` that reads the current state in its `process` method (see Custom Event Processors)

Replace `TelemetryDeck.signal(...)` calls with `TelemetryDeck.event(...)` — the call sites require no other changes.

## Developing this SDK

Your PRs on TelemetryDeck's Swift SDK are very much welcome. Check out the [SwiftClientTester](https://github.com/TelemetryDeck/SwiftClientTester) project, which provides a harness you can use to work on the library and try out new things.

When making a new release, run `./tag-release.sh MAJOR.MINOR.PATCH` to bump the version string in the SDK, create a new commit and tag that commit accordingly all in one step.

The project includes a Makefile at the root with some useful commands:

- `build`: Build the library
- `lint`:  Applies all auto-correctable lint issues and reformats all source files
- `test`:  Run unit tests

Before finalising your PR, please run `make lint`.
