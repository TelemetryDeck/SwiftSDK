//
//  SwiftClientTesterApp.swift
//  SwiftClientTester
//
//  Created by Daniel Jilg on 22.06.21.
//

import SwiftUI
#if os(watchOS)
    import TelemetryClient_WatchOS
#else
    import TelemetryClient
#endif

@main
struct SwiftClientTesterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        let configuration = TelemetryManagerConfiguration(
            appID: "FA469AE1-1D1B-419D-B74C-0748C0325AFC"
        )
        configuration.telemetryAllowDebugBuilds = true
        configuration.showDebugLogs = true
        TelemetryManager.initialize(with: configuration)

        TelemetryManager.send("applicationDidFinishLaunching", with: ["test":"test", "test2":"test2"])
    }
}
