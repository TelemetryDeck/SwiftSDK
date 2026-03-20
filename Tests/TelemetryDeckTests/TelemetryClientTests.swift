//
//  TelemetryClientTests.swift
//  TelemetryDeck
//
//  Created by Konstantin on 17/11/2025.
//

import Foundation
import Testing

@testable import TelemetryDeck

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

    @Test
    func `SignalManager preserves base URL path components`() {
        let baseURL = URL(string: "https://example.com/array/sensors")!
        let result = SignalManager.getServiceUrl(baseURL: baseURL)

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/array/sensors/v2/")
    }

    @Test
    func `SignalManager preserves base URL path components with trailing slash`() {
        let baseURL = URL(string: "https://example.com/array/sensors/")!
        let result = SignalManager.getServiceUrl(baseURL: baseURL)

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/array/sensors/v2/")
    }

    @Test
    func `SignalManager preserves base URL path components with namespace`() {
        let baseURL = URL(string: "https://example.com/array/sensors")!
        let result = SignalManager.getServiceUrl(baseURL: baseURL, namespace: "deltaquadrant")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/array/sensors/v2/namespace/deltaquadrant/")
    }

    @Test
    func `SignalManager preserves base URL path components with trailing slash and namespace`() {
        let baseURL = URL(string: "https://example.com/array/sensors/")!
        let result = SignalManager.getServiceUrl(baseURL: baseURL, namespace: "deltaquadrant")

        #expect(result != nil)
        #expect(result?.absoluteString == "https://example.com/array/sensors/v2/namespace/deltaquadrant/")
    }
}
