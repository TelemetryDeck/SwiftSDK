import Foundation
import Testing

@testable import TelemetryDeck

struct EventCodableTests {
    @Test
    func signalEncodesAndDecodesWithTelemetryEncoder() throws {
        let originalEvent = Event(
            appID: "test-app-id",
            type: "TestEvent",
            clientUser: "user123",
            sessionID: "session-abc",
            receivedAt: Date(timeIntervalSince1970: 1_609_459_200),
            payload: ["key1": "value1", "key2": "value2"],
            floatValue: 42.5,
            isTestMode: true
        )

        let encoded = try JSONEncoder.telemetryEncoder.encode(originalEvent)
        let decoded = try JSONDecoder.telemetryDecoder.decode(Event.self, from: encoded)

        #expect(decoded.appID == originalEvent.appID)
        #expect(decoded.type == originalEvent.type)
        #expect(decoded.clientUser == originalEvent.clientUser)
        #expect(decoded.sessionID == originalEvent.sessionID)
        #expect(decoded.receivedAt.timeIntervalSince1970 == originalEvent.receivedAt.timeIntervalSince1970)
        #expect(decoded.payload == originalEvent.payload)
        #expect(decoded.floatValue == originalEvent.floatValue)
        #expect(decoded.isTestMode == originalEvent.isTestMode)
    }

    @Test
    func dateFormattedCorrectly() throws {
        let knownDate = Date(timeIntervalSince1970: 1_609_459_200)
        let signal = Event(
            appID: "test-app-id",
            type: "TestEvent",
            clientUser: "user123",
            sessionID: "session-abc",
            receivedAt: knownDate,
            payload: [:],
            floatValue: nil,
            isTestMode: false
        )

        let encoded = try JSONEncoder.telemetryEncoder.encode(signal)
        let jsonString = String(data: encoded, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString?.contains("2021-01-01T00:00:00+0000") == true)
    }

    @Test
    func isTestModeTrueEncodesAsStringTrue() throws {
        let signal = Event(
            appID: "test-app-id",
            type: "TestEvent",
            clientUser: "user123",
            sessionID: "session-abc",
            receivedAt: Date(),
            payload: [:],
            floatValue: nil,
            isTestMode: true
        )

        let encoded = try JSONEncoder.telemetryEncoder.encode(signal)
        let decoded = try JSONDecoder.telemetryDecoder.decode(Event.self, from: encoded)

        #expect(decoded.isTestMode == "true")
    }

    @Test
    func floatValueNilRoundtrips() throws {
        let signal = Event(
            appID: "test-app-id",
            type: "TestEvent",
            clientUser: "user123",
            sessionID: "session-abc",
            receivedAt: Date(),
            payload: ["key": "value"],
            floatValue: nil,
            isTestMode: false
        )

        let encoded = try JSONEncoder.telemetryEncoder.encode(signal)
        let decoded = try JSONDecoder.telemetryDecoder.decode(Event.self, from: encoded)

        #expect(decoded.floatValue == nil)
    }

    @Test
    func emptyPayloadRoundtrips() throws {
        let signal = Event(
            appID: "test-app-id",
            type: "TestEvent",
            clientUser: "user123",
            sessionID: "session-abc",
            receivedAt: Date(),
            payload: [:],
            floatValue: nil,
            isTestMode: false
        )

        let encoded = try JSONEncoder.telemetryEncoder.encode(signal)
        let decoded = try JSONDecoder.telemetryDecoder.decode(Event.self, from: encoded)

        #expect(decoded.payload.isEmpty)
        #expect(decoded.payload == [:])
    }
}
