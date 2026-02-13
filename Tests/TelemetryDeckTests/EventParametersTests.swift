import Foundation
import Testing

@testable import TelemetryDeck

struct EventParametersTests {
    @Test
    func dictionaryLiteralInit() {
        let params: EventParameters = [
            "key1": "value1",
            "key2": 42,
            "key3": true,
        ]

        #expect(params["key1"] as? String == "value1")
        #expect(params["key2"] as? Int == 42)
        #expect(params["key3"] as? Bool == true)
    }

    @Test
    func mergeBehavior() {
        var params1: EventParameters = ["key1": "original", "key2": "stays"]
        let params2: EventParameters = ["key1": "override", "key3": "new"]

        params1.merge(params2)

        #expect(params1["key1"] as? String == "override")
        #expect(params1["key2"] as? String == "stays")
        #expect(params1["key3"] as? String == "new")
    }

    @Test
    func mergeStringDictionary() {
        var params: EventParameters = ["key1": "value1"]
        let stringDict = ["key2": "value2", "key1": "override"]

        params.merge(stringDict)

        #expect(params["key1"] as? String == "override")
        #expect(params["key2"] as? String == "value2")
    }

    @Test
    func stringDictionaryConvertsTypes() {
        let params: EventParameters = [
            "stringValue": "hello",
            "intValue": 42,
            "doubleValue": 3.14,
            "boolValue": true,
            "uuidValue": UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            "dateValue": Date(timeIntervalSince1970: 0),
        ]

        let stringDict = params.stringDictionary

        #expect(stringDict["stringValue"] == "hello")
        #expect(stringDict["intValue"] == "42")
        #expect(stringDict["doubleValue"] == "3.14")
        #expect(stringDict["boolValue"] == "true")
        #expect(stringDict["uuidValue"] == "12345678-1234-1234-1234-123456789012")
        #expect(stringDict["dateValue"]?.contains("1970-01-01") == true)
    }

    @Test
    func subscriptGetAndSet() {
        var params = EventParameters()

        params["key1"] = "value1"
        #expect(params["key1"] as? String == "value1")

        params["key1"] = "updated"
        #expect(params["key1"] as? String == "updated")

        params["key1"] = nil
        #expect(params["key1"] == nil)
    }

    @Test
    func countAndIsEmpty() {
        var params = EventParameters()
        #expect(params.isEmpty)
        #expect(params.count == 0)

        params["key1"] = "value1"
        #expect(!params.isEmpty)
        #expect(params.count == 1)

        params["key2"] = "value2"
        #expect(params.count == 2)
    }

    @Test
    func iterationOverParameters() {
        let params: EventParameters = [
            "key1": "value1",
            "key2": 42,
        ]

        var foundKeys = Set<String>()
        for (key, _) in params {
            foundKeys.insert(key)
        }

        #expect(foundKeys.contains("key1"))
        #expect(foundKeys.contains("key2"))
        #expect(foundKeys.count == 2)
    }

    @Test
    func keysProperty() {
        let params: EventParameters = [
            "key1": "value1",
            "key2": "value2",
        ]

        let keys = Set(params.keys)
        #expect(keys.contains("key1"))
        #expect(keys.contains("key2"))
        #expect(keys.count == 2)
    }

    @Test
    func parameterValueConversions() {
        #expect("hello".parameterStringValue == "hello")
        #expect(true.parameterStringValue == "true")
        #expect(false.parameterStringValue == "false")
        #expect(42.parameterStringValue == "42")
        #expect(Int64(100).parameterStringValue == "100")
        #expect(3.14.parameterStringValue == "3.14")
        #expect(Float(2.5).parameterStringValue == "2.5")

        let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        #expect(uuid.parameterStringValue == "12345678-1234-1234-1234-123456789012")

        let date = Date(timeIntervalSince1970: 0)
        #expect(date.parameterStringValue.contains("1970"))
    }
}
