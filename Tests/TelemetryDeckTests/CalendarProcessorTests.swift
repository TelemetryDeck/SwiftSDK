import Foundation
import Testing

@testable import TelemetryDeck

struct CalendarProcessorTests {
    let testConfig = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    @Test
    func calendarProcessorAddsDateComponents() async throws {
        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )

        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        #expect(signal.payload["TelemetryDeck.Calendar.dayOfMonth"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.dayOfWeek"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.dayOfYear"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.weekOfYear"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.isWeekend"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.monthOfYear"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.quarterOfYear"] != nil)
        #expect(signal.payload["TelemetryDeck.Calendar.hourOfDay"] != nil)
    }

    @Test
    func weekdayMappingSundayIsSeven() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: 2025, month: 1, day: 5)
        let sunday = calendar.date(from: components)!

        let sundayWeekday = calendar.component(.weekday, from: sunday)
        #expect(sundayWeekday == 1)

        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        let calendar2 = Calendar(identifier: .gregorian)
        let nowComponents = calendar2.dateComponents([.weekday], from: input.timestamp)
        let expectedDayOfWeek = nowComponents.weekday.map { $0 == 1 ? 7 : $0 - 1 } ?? -1

        if case .int(let dayOfWeek) = signal.payload["TelemetryDeck.Calendar.dayOfWeek"] {
            #expect(Int(dayOfWeek) == expectedDayOfWeek)
        } else {
            Issue.record("dayOfWeek not found in payload")
        }
    }

    @Test
    func hourRangeIs1To24() async throws {
        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        if case .int(let hour) = signal.payload["TelemetryDeck.Calendar.hourOfDay"] {
            #expect(hour >= 1)
            #expect(hour <= 24)
        } else {
            Issue.record("hourOfDay not found in payload")
        }
    }

    @Test
    func weekendDetection() async throws {
        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        let calendar = Calendar(identifier: .gregorian)
        let nowComponents = calendar.dateComponents([.weekday], from: input.timestamp)
        let dayOfWeek = nowComponents.weekday.map { $0 == 1 ? 7 : $0 - 1 } ?? -1
        let expectedIsWeekend = dayOfWeek >= 6

        if case .bool(let isWeekend) = signal.payload["TelemetryDeck.Calendar.isWeekend"] {
            #expect(isWeekend == expectedIsWeekend)
        } else {
            Issue.record("isWeekend not found in payload")
        }
    }

    @Test
    func quarterCalculation() async throws {
        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        if case .int(let quarter) = signal.payload["TelemetryDeck.Calendar.quarterOfYear"] {
            #expect(quarter >= 1)
            #expect(quarter <= 4)
        } else {
            Issue.record("quarterOfYear not found in payload")
        }
    }

    @Test
    func weekOfYear() async throws {
        let processor = CalendarProcessor()
        let pipeline = ProcessorPipeline(
            processors: [processor],
            finalizer: EventFinalizer(configuration: testConfig)
        )
        let input = EventInput("Test.signal")
        let context = EventContext()
        let signal = try await pipeline.process(input, context: context)

        if case .int(let week) = signal.payload["TelemetryDeck.Calendar.weekOfYear"] {
            #expect(week >= 1)
            #expect(week <= 53)
        } else {
            Issue.record("weekOfYear not found in payload")
        }
    }
}
