@testable import TelemetryDeck
import Testing

enum ArrayExtensionTests {
    enum CountISODatesOnOrAfter {
        @Test
        static func typicalCase() {
            let dates = ["2025-01-01", "2025-01-15", "2025-02-01", "2025-03-01"]

            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2025-01-15") == 3)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2025-02-01") == 2)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2025-03-02") == 0)
        }

        @Test
        static func edgeCases() {
            // Empty array
            let emptyDates: [String] = []
            #expect(emptyDates.countISODatesOnOrAfter(cutoffISODate: "2025-01-01") == 0)

            // Single date, various cutoffs
            let singleDate = ["2025-01-15"]
            #expect(singleDate.countISODatesOnOrAfter(cutoffISODate: "2025-01-14") == 1)
            #expect(singleDate.countISODatesOnOrAfter(cutoffISODate: "2025-01-15") == 1)
            #expect(singleDate.countISODatesOnOrAfter(cutoffISODate: "2025-01-16") == 0)
        }

        @Test
        static func duplicateDates() {
            let datesWithDuplicates = [
                "2025-01-01",
                "2025-01-01",  // Duplicate
                "2025-02-01",
                "2025-02-01",  // Duplicate
                "2025-03-01"
            ]

            #expect(datesWithDuplicates.countISODatesOnOrAfter(cutoffISODate: "2025-01-01") == 5)
            #expect(datesWithDuplicates.countISODatesOnOrAfter(cutoffISODate: "2025-02-01") == 3)
            #expect(datesWithDuplicates.countISODatesOnOrAfter(cutoffISODate: "2025-03-01") == 1)
        }

        @Test
        static func complexDateRanges() {
            let dates = [
                "2020-12-31",  // End of 2020
                "2021-01-01",  // Start of 2021
                "2021-12-31",  // End of 2021
                "2022-01-01",  // Start of 2022
                "2022-09-30",  // End of September
                "2022-10-01",  // Start of October
                "2023-01-09",  // Single digit day
                "2023-01-10",  // Double digit day
                "2023-09-09",  // Both single digit
                "2023-09-10",  // Mixed digits
                "2023-10-09",  // Mixed digits different order
                "2023-10-10",  // Both double digits
                "2024-02-28",  // End of February
                "2024-02-29",  // Leap year day
                "2024-03-01",  // Start of March
                "2025-01-01"   // Far future
            ]

            // Test year boundaries
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2020-12-31") == 16)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2021-01-01") == 15)

            // Test month transitions
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2022-09-30") == 12)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2022-10-01") == 11)

            // Test single/double digit transitions
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2023-01-09") == 10)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2023-01-10") == 9)

            // Test leap year period
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2024-02-28") == 4)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2024-02-29") == 3)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2024-03-01") == 2)

            // Test future date
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2025-01-01") == 1)
            #expect(dates.countISODatesOnOrAfter(cutoffISODate: "2025-01-02") == 0)
        }
    }
}
