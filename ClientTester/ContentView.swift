//
//  ContentView.swift
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

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Push this button to send 100 Boops!")
            Button("100x Boop") {
                for x in 0 ..< 100 {
                    TelemetryManager.send("boop", with: ["test":"\(x)"])
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
