# TelemetryClient

It's recommended you create an enum of signal types:

```
enum TelemetrySignalType: String {
    case appLaunchedRegularly
    case appLaunchedFromNotification
    case pizzaModeActivated
}
```

Init the Telemetry Manager at app startup, so it knows your App ID (you can retrieve the App ID in the Telemetry Viewer app, under App Settings)

````
let configuration = TelemetryManagerConfiguration(appID: "<YOUR-APP-ID>")
TelemetryManager.initialize(with: configuration)
````

For example, if you're building a scene based app, in the `init()` function for your `App`:

```
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

```
TelemetryManager.shared.send("appOpenedRegularly")
```

Telemetry Manager will create a user identifier for you user that is specific to app installation and device. If you have a better user identifier available, you can use that instead: (the identifier will be hashed before sending it) 

```
TelemetryManager.shared.send("userLoggedIn", for: "email")
```

You can also send additional payload data with each signal:

```
TelemetryManager.shared.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])
```

Telemetry Manager will automatically send a base payload with these keys: 

- platform
- systemVersion
- appVersion
- buildNumber
- isSimulator
- isTestFlight
- isAppStore 
