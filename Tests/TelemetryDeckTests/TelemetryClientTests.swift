//
//  TelemetryClientTests.swift
//  TelemetryDeck
//
//  Created by Konstantin on 17/11/2025.
//

@testable import TelemetryDeck
import Testing
import Foundation

struct TelemetryClientTests {
    
    @Test
    func `SignalManager creates correct service url`() {
        
        let config = TelemetryManagerConfiguration(appID: "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3")
        let result = SignalManager.getServiceUrl(baseURL: config.apiBaseURL)
        
        #expect(result != nil)
        #expect(result?.absoluteString == "https://nom.telemetrydeck.com/v2/")
    }
    
    @Test
    func `SignalManager creates correct service url with namespace`() {
        
        let config = TelemetryManagerConfiguration(appID: "44e0f59a-60a2-4d4a-bf27-1f96ccb4aaa3")
        let result = SignalManager.getServiceUrl(baseURL: config.apiBaseURL, namespace: "deltaquadrant")
        
        
        #expect(result != nil)
        #expect(result?.absoluteString == "https://nom.telemetrydeck.com/v2/namespace/deltaquadrant/")
    }
}
