# TelemetryClient

Init the Telemetry Manager at app startup, so it knows your App ID (you can retrieve the App ID in the Telemetry Viewer app, under App Settings)

````swift
let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
// optional: modify the configuration here
TelemetryManager.initialize(with: configuration)
````

For example, if you're building a scene based app, in the `init()` function for your `App`:

```swift
import SwiftUI
import TelemetryClient

@main
struct TelemetryTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        // Note: Do not add this code to `WindowGroup.onAppear`, which will be called 
        //       *after* your window has been initialized, and might lead to out initialization
        //       occurring too late.
        let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
        TelemetryManager.initialize(with: configuration)
    }
}
```

Then send signals like so: 

```swift
TelemetryManager.send("appLaunchedRegularly")
```

## Debug Mode

Telemetry Manager will *not* send any signals if your scheme's build configuration is set to "Debug", e.g if `#if DEBUG` would evaluate to `true`. You can override this by setting `configuration.sendSignalsInDebugConfiguration = true` on your `TelemetryManagerConfiguration` instance.


## User Identifiers
Telemetry Manager will create a user identifier for you user that is specific to app installation and device. If you have a better user identifier available, such as an email address or a username, you can use that instead, by passing it on to the `TelemetryManagerConfiguration` (the identifier will be hashed before sending it).

```swift
configuration.defaultUser = "myuser@example.com"
```

You can update the configuration after TelemetryManager is already initialized.

## Payload
You can also send additional payload data with each signal:

```swift
TelemetryManager.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])
```

Telemetry Manager will automatically send a base payload with these keys: 

- platform
- systemVersion
- appVersion
- buildNumber
- isSimulator
- isTestFlight
- isAppStore 
- modelName
- architecture
- operatingSystem
- targetEnvironment

## Sessions

With each Signal, the client sends a hash of your user ID as well as a *session ID*. This gets automatically generated when the client is initialized, so if you do nothing, you'll get a new session each time your app is started from cold storage.

On iOS, tvOS, and watchOS, the session identifier will automatically update whenever your app returns from background, or if it is launched from cold storage. On other platforms, a new identifier will be generated each time your app launches. If you'd like more fine-grained session support, write a new random session identifier into the `TelemetryManagerConfiguration`'s `sessionID` property each time a new session begins.
