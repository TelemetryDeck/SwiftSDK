import Foundation

/// Enriches events with Gregorian calendar context derived from the event timestamp.
public struct CalendarProcessor: EventProcessor {
    /// Creates a calendar processor.
    public init() {}

    /// Adds day, week, month, quarter, hour, and weekend flag parameters to the context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context

        let calendar = Calendar(identifier: .gregorian)
        let nowDate = input.timestamp
        let components = calendar.dateComponents([.day, .weekday, .weekOfYear, .month, .hour, .quarter, .yearForWeekOfYear], from: nowDate)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: nowDate) ?? -1
        let dayOfWeek = components.weekday.map { $0 == 1 ? 7 : $0 - 1 } ?? -1
        let isWeekend = dayOfWeek >= 6

        context.addParameter(DefaultParams.Calendar.dayOfMonth, value: components.day ?? -1)
        context.addParameter(DefaultParams.Calendar.dayOfWeek, value: dayOfWeek)
        context.addParameter(DefaultParams.Calendar.dayOfYear, value: dayOfYear)
        context.addParameter(DefaultParams.Calendar.weekOfYear, value: components.weekOfYear ?? -1)
        context.addParameter(DefaultParams.Calendar.isWeekend, value: isWeekend)
        context.addParameter(DefaultParams.Calendar.monthOfYear, value: components.month ?? -1)
        context.addParameter(DefaultParams.Calendar.quarterOfYear, value: components.quarter ?? -1)
        context.addParameter(DefaultParams.Calendar.hourOfDay, value: (components.hour ?? -1) + 1)

        return try await next(input, context)
    }
}
