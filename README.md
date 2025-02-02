# Swift SDK for TelemetryDeck

This package allows you to send signals to [TelemetryDeck](https://telemetrydeck.com) from your Swift code. Sign up for a free account at telemetrydeck.com

## Installation

The easiest way to install TelemetryDeck is using [Swift Package Manager](https://www.swift.org/package-manager/), Apple's solution which is built into Xcode. In Xcode, press _File > Add Packages..._, then in the resulting window enter `https://github.com/TelemetryDeck/SwiftSDK` into the search field. Set the _Dependency Rule_ field to _Up to Next Major Version_, then press the _Add Package_ button. Xcode will download it, then you can choose which target of your app to add the "TelemetryDeck" library to (note that "TelemetryClient" is the old name of the lib).

See our [detailed setup guide](https://telemetrydeck.com/docs/guides/swift-setup/?source=github) for more information.

## Initialization

Init the Telemetry Manager at app startup, so it knows your App ID (you can retrieve the App ID from your [TelemetryDeck Dashboard](https://dashboard.telemetrydeck.com/) under Set Up App)

```swift
let config = TelemetryDeck.Config(appID: "<YOUR-APP-ID>")
// optional: modify the config here
TelemetryDeck.initialize(config: config)
```

For example, if you're building a scene based app, in the `init()` function for your `App`:

```swift
import SwiftUI
import TelemetryDeck

@main
struct TelemetryTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        // Note: Do not add this code to `WindowGroup.onAppear`, which will be called
        //       *after* your window has been initialized, and might lead to our initialization
        //       occurring too late.
        let config = TelemetryDeck.Config(appID: "<YOUR-APP-ID>")
        TelemetryDeck.initialize(config: config)
    }
}
```

Then send signals like so:

```swift
TelemetryDeck.signal("App.launchedRegularly")
```

## Debug -> Test Mode

If your app's build configuration is set to "Debug", all signals sent will be marked as testing signals. In the Telemetry Viewer app, activate **Test Mode** to see those.

If you want to manually control whether test mode is active, you can set the `config.testMode` property.

## User Identifiers

Telemetry Manager will create a user identifier for you user that is specific to app installation and device. If you have a better user identifier available, such as an email address or a username, you can use that instead, by passing it on to the `TelemetryDeck.Config` (the identifier will be hashed before sending it).

```swift
config.defaultUser = "myuser@example.com"
```

You can update the configuration after TelemetryDeck is already initialized.

## Parameters

You can also send additional parameters with each signal:

```swift
TelemetryDeck.signal("Database.updated", parameters: ["numberOfDatabaseEntries": "3831"])
```

TelemetryDeck will automatically send base parameters, such as:

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

See our [Grand Renaming article](https://telemetrydeck.com/docs/articles/grand-rename/?source=github) for a full list.

## App Extensions Support

When using this SDK in an app extension target, add `TARGET_APP_EXTENSION` to your build settings to ensure extension-safe API usage:

1. In Xcode, select your app extension target
2. Go to "Build Settings"
3. Find "Active Compilation Conditions"
4. Add `TARGET_APP_EXTENSION` to the Debug and Release configurations

![App Extension Build Settings](Images/TARGET_APP_EXTENSION.jpeg)

> [!TIP]
> You can can also just **copy** the following two lines, select the build setting and **paste** them in:
> ```
> SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Debug] = TARGET_APP_EXTENSION DEBUG
> SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=Release] = TARGET_APP_EXTENSION
> ```

> [!NOTE]
> Only add this compilation condition to **extension** targets, not to your main app target.

## Sessions

With each Signal, the client sends a hash of your user ID as well as a _session ID_. This gets automatically generated when the client is initialized, so if you do nothing, you'll get a new session each time your app is started from cold storage.

On iOS, tvOS, and watchOS, the session identifier will automatically update whenever your app returns from background, or if it is launched from cold storage. On other platforms, a new identifier will be generated each time your app launches. If you'd like more fine-grained session support, write a new random session identifier into the `TelemetryDeck.Config`'s `sessionID` property each time a new session begins.

## Custom Salt

By default, user identifiers are hashed by the TelemetryDeck SDK, and then sent to the Ingestion API, where we'll add a salt to the received identifier and hash it again.

This is enough for most use cases, but if you want to extra privacy conscious, you can add in you own salt on the client side. The TelemetryDeck SDK will append the salt to all user identifers before hashing them and sending them to us.

If you'd like to use a custom salt, you can do so by passing it on to the `TelemetryDeck.Config`

```swift
let config = TelemetryDeck.Config(appID: "<YOUR-APP-ID>", salt: "<A RANDOM STRING>")
```

## Custom Server

A very small subset of our customers will want to use a custom signal ingestion server or a custom proxy server. To do so, you can pass the URL of the custom server to the `TelemetryDeck.Config`:

```swift
let config = TelemetryDeck.Config(appID: "<YOUR-APP-ID>", baseURL: "https://nom.telemetrydeck.com")
```

## Custom Logging Strategy

By default, some logs helpful for monitoring TelemetryDeck are printed out to the console. This behaviour can be customised by overriding `config.logHandler`. This struct accepts a minimum allows log level (any log with the same or higher log level will be accepted) and a closure.

This allows for compatibility with other logging solutions, such as [swift-log](https://github.com/apple/swift-log), by providing your own closure.

## Developing this SDK

Your PRs on TelemetryDeck's Swift SDK are very much welcome. Check out the [SwiftClientTester](https://github.com/TelemetryDeck/SwiftClientTester) project, which provides a harness you can use to work on the library and try out new things.

When making a new release, run `./tag-release.sh MAJOR.MINOR.PATCH` to bump the version string in the SDK, create a new commit and tag that commit accordingly all in one step.
