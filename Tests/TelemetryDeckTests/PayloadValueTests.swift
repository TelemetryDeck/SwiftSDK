import Foundation
import Testing

@testable import TelemetryDeck

struct PayloadValueTests {

    // MARK: - Encoding

    @Test
    func stringEncodesToJSONString() throws {
        let encoded = try JSONEncoder().encode(PayloadValue.string("hello"))
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "\"hello\"")
    }

    @Test
    func intEncodesToJSONNumber() throws {
        let encoded = try JSONEncoder().encode(PayloadValue.int(42))
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "42")
    }

    @Test
    func doubleEncodesToJSONNumber() throws {
        let encoded = try JSONEncoder().encode(PayloadValue.double(3.14))
        let decoded = try JSONDecoder().decode(Double.self, from: encoded)
        #expect(abs(decoded - 3.14) < 1e-10)
    }

    @Test
    func boolTrueEncodesToJSONTrue() throws {
        let encoded = try JSONEncoder().encode(PayloadValue.bool(true))
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "true")
    }

    @Test
    func boolFalseEncodesToJSONFalse() throws {
        let encoded = try JSONEncoder().encode(PayloadValue.bool(false))
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "false")
    }

    // MARK: - Decoding

    @Test
    func jsonStringDecodesAsString() throws {
        let data = Data("\"hello\"".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value == .string("hello"))
    }

    @Test
    func jsonIntegerDecodesAsInt() throws {
        let data = Data("42".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value == .int(42))
    }

    @Test
    func jsonDecimalDecodesAsDouble() throws {
        let data = Data("3.14".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value == .double(3.14))
    }

    @Test
    func jsonTrueDecodesAsBool() throws {
        let data = Data("true".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value == .bool(true))
    }

    @Test
    func jsonFalseDecodesAsBool() throws {
        let data = Data("false".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value == .bool(false))
    }

    // MARK: - Round-trip precision

    @Test
    func doubleRoundTripsExactly() throws {
        let original = PayloadValue.double(3.14)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PayloadValue.self, from: encoded)
        #expect(decoded == original)
    }

    // MARK: - Bool/number discrimination

    @Test
    func jsonTrueIsNotDecodedAsDouble() throws {
        let data = Data("true".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value != .double(1.0))
    }

    @Test
    func jsonFalseIsNotDecodedAsDouble() throws {
        let data = Data("false".utf8)
        let value = try JSONDecoder().decode(PayloadValue.self, from: data)
        #expect(value != .double(0.0))
    }

    // MARK: - Literal conformances

    @Test
    func stringLiteralConformance() {
        let v: PayloadValue = "hello"
        #expect(v == .string("hello"))
    }

    @Test
    func integerLiteralConformance() {
        let v: PayloadValue = 42
        #expect(v == .int(42))
    }

    @Test
    func floatLiteralConformance() {
        let v: PayloadValue = 3.14
        #expect(v == .double(3.14))
    }

    @Test
    func booleanLiteralConformance() {
        let v: PayloadValue = true
        #expect(v == .bool(true))
    }

    // MARK: - Mixed-type Event encoding

    @Test
    func mixedPayloadEncodesToNativeJSONTypes() throws {
        let event = Event(
            appID: "test-app",
            type: "Test.mixed",
            clientUser: "user-hash",
            sessionID: nil,
            receivedAt: Date(timeIntervalSince1970: 0),
            payload: [
                "label": .string("hello"),
                "count": .int(7),
                "ratio": .double(0.5),
                "active": .bool(true),
            ],
            floatValue: nil,
            isTestMode: false
        )

        let data = try JSONEncoder.telemetryEncoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let payload = json["payload"] as! [String: Any]

        #expect(payload["label"] as? String == "hello")
        #expect(payload["count"] as? Int == 7)
        #expect((payload["ratio"] as? Double).map { abs($0 - 0.5) < 0.0001 } == true)
        #expect(payload["active"] as? Bool == true)
    }

    // MARK: - Backward compatibility: old string-only payload

    @Test
    func oldStringOnlyPayloadDecodesIntoEvent() throws {
        let json = """
            {
                "appID": "test-app",
                "type": "Legacy.event",
                "clientUser": "hash",
                "receivedAt": "2021-01-01T00:00:00+0000",
                "payload": {"key": "value", "count": "42"},
                "isTestMode": "false"
            }
            """.data(using: .utf8)!

        let event = try JSONDecoder.telemetryDecoder.decode(Event.self, from: json)
        #expect(event.payload["key"] == .string("value"))
        #expect(event.payload["count"] == .string("42"))
    }
}
