import Foundation
import Testing

@testable import TelemetryDeck

struct EventContextTests {
    @Test
    func addParameterStoresValue() {
        var context = EventContext()

        context.addParameter("stringKey", value: "stringValue")
        context.addParameter("intKey", value: 42)
        context.addParameter("boolKey", value: true)

        #expect(context.metadata["stringKey"] as? String == "stringValue")
        #expect(context.metadata["intKey"] as? Int == 42)
        #expect(context.metadata["boolKey"] as? Bool == true)
    }

    @Test
    func removeParameterDeletesKey() {
        var context = EventContext()

        context.addParameter("key1", value: "value1")
        #expect(context.metadata["key1"] as? String == "value1")

        context.removeParameter("key1")
        #expect(context.metadata["key1"] == nil)
    }

    @Test
    func addParametersDictionaryMergesAll() {
        var context = EventContext()

        let dictionary = [
            "key1": "value1",
            "key2": "value2",
            "key3": "value3",
        ]

        context.addParameters(dictionary)

        #expect(context.metadata["key1"] as? String == "value1")
        #expect(context.metadata["key2"] as? String == "value2")
        #expect(context.metadata["key3"] as? String == "value3")
    }

    @Test
    func addParametersEventParametersMergesAll() {
        var context = EventContext()

        let params: EventParameters = [
            "stringParam": "stringValue",
            "intParam": 42,
            "boolParam": true,
        ]

        context.addParameters(params)

        #expect(context.metadata["stringParam"] as? String == "stringValue")
        #expect(context.metadata["intParam"] as? Int == 42)
        #expect(context.metadata["boolParam"] as? Bool == true)
    }
}
