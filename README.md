# TelemetryClient

It's recommended you create an enum of signal types:

```
enum TelemetrySignalType: String {
    case appLaunchedRegularly
    case appLaunchedFromNotification
    case pizzaModeActivated
}
```

Init the Telemetry Manager and store it somewhere:

````
let configuration = TelemetryManagerConfiguration(telemetryAppID: "<YOUR-APP-ID>")
let telemetryManager = TelemetryManager(configuration: configuration)
````

Then send signals like so: 

```
telemetryManager.send("appOpenedRegularly")
```

Telemetry Manager will create a user identifier for you user that is specific to app installation and device. If you have a better user identifier available, you can use that instead: (the identifier will be hashed before sending it) 

```
telemetryManager.send("userLoggedIn", for: user.email)
```

You can also send additional payload data with each signal:

```
telemetryManager.send("databaseUpdated", with: ["numberOfDatabaseEntries": "3831"])
```

Telemetry Manager will automatically send a base payload with these keys: 

- platform
- systemVersion
- appVersion
- buildNumber
- isSimulator
- isTestFlight
- isAppStore 
