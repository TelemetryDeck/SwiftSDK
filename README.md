# TelemetryClient

Init the Telemetry Manager at app startup, so it knows your App ID (you can retrieve the App ID in the Telemetry Viewer app, under App Settings)

````swift
let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
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

Telemetry Manager will create a user identifier for you user that is specific to app installation and device. If you have a better user identifier available, you can use that instead: (the identifier will be hashed before sending it) 

```swift
TelemetryManager.send("userLoggedIn", for: "email")
```

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

NOTE: Telemetry Manager will *not* send any signals if you are in DEBUG Mode. You can override this by setting `configuration.telemetryAllowDebugBuilds = true` on your `TelemetryManagerConfiguration` instance.

## Sessions

With each Signal, the client sends a hash of your user ID as well as a *session ID*. This gets automatically generated when the client is initialized, so if you do nothing, you'll get a new session each time your app is started from cold storage.

If you want to manually start a new sesion, call `TelemetryManager.generateNewSession()`. For example, with mobile apps, you usually want to start a new session when the app returns from background. In Swiftui, you can do this by listening to the `scenePhase` property of a your `App`. Here's how to do that in your `Your_App.swift`, the main entry point into you app:

```swift
import SwiftUI
import TelemetryClient

@main
struct TelemetryTestApp: App {
    var body: some Scene {
        
        // (1) Add the scenePhase env var to your App
        @Environment(\.scenePhase) var scenePhase
    
        WindowGroup {
            ContentView()
        }
        
        // (2) Generate a new session whenever the scenePhase returns back to "active", i.e. the app returns from background
        .onChange(of: scenePhase) { newScenePhase in
            if newScenePhase == .active {
                TelemetryManager.generateNewSession()
            }
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
