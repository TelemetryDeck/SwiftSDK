import Foundation
import Testing

@testable import TelemetryDeck

@Suite
struct V2DataMigrationTests {
    private let testConfig = TelemetryDeck.Config(appID: "test-app", namespace: "test-ns")

    @Test
    func recentSessionsWithEpochTimestampsAreMigratedToReferenceDate() async throws {
        let storage = InMemoryProcessorStorage()

        let epochTimestamp = Date().addingTimeInterval(-200).timeIntervalSince1970
        let v2JSON = "[{\"st\":\(epochTimestamp),\"dn\":42}]".data(using: .utf8)!
        await storage.set(v2JSON, forKey: "recentSessions")

        await V2DataMigrator.migrateIfNeeded(storage: storage)

        let migratedData = await storage.data(forKey: "recentSessions")
        #expect(migratedData != nil)

        let migratedDate = decodedSessionDate(from: migratedData!)
        #expect(migratedDate != nil)
        let expectedDate = Date(timeIntervalSince1970: epochTimestamp)
        #expect(abs(migratedDate!.timeIntervalSince(expectedDate)) < 1)
    }

    @Test
    func distinctDaysUsedPlistArrayIsMigratedToJSONSet() async throws {
        let storage = InMemoryProcessorStorage()

        await storage.setStringArray(["2025-01-01", "2025-01-02", "2025-01-03"], forKey: "distinctDaysUsed")
        await storage.set("[{\"st\":\(Date().timeIntervalSince1970),\"dn\":0}]".data(using: .utf8)!, forKey: "recentSessions")

        await V2DataMigrator.migrateIfNeeded(storage: storage)

        let migratedData = await storage.data(forKey: "distinctDaysUsed")
        #expect(migratedData != nil)

        let migratedDays = try JSONDecoder().decode(Set<String>.self, from: migratedData!)
        #expect(migratedDays == ["2025-01-01", "2025-01-02", "2025-01-03"])
    }

    @Test
    func installIDIsSetAfterMigration() async throws {
        let storage = InMemoryProcessorStorage()

        let epochTimestamp = Date().addingTimeInterval(-100).timeIntervalSince1970
        await storage.set("[{\"st\":\(epochTimestamp),\"dn\":10}]".data(using: .utf8)!, forKey: "recentSessions")

        #expect(await storage.string(forKey: "installID") == nil)

        await V2DataMigrator.migrateIfNeeded(storage: storage)

        let installID = await storage.string(forKey: "installID")
        #expect(installID != nil)
        #expect(UUID(uuidString: installID!) != nil)
    }

    @Test
    func migrationIsIdempotent() async throws {
        let storage = InMemoryProcessorStorage()

        let epochTimestamp = Date().addingTimeInterval(-100).timeIntervalSince1970
        await storage.set("[{\"st\":\(epochTimestamp),\"dn\":10}]".data(using: .utf8)!, forKey: "recentSessions")

        await V2DataMigrator.migrateIfNeeded(storage: storage)
        let installIDAfterFirst = await storage.string(forKey: "installID")
        let dataAfterFirst = await storage.data(forKey: "recentSessions")

        await V2DataMigrator.migrateIfNeeded(storage: storage)
        let installIDAfterSecond = await storage.string(forKey: "installID")
        let dataAfterSecond = await storage.data(forKey: "recentSessions")

        #expect(installIDAfterFirst == installIDAfterSecond)
        #expect(dataAfterFirst == dataAfterSecond)
    }

    @Test
    func freshInstallWithNoV2DataIsUnaffected() async throws {
        let storage = InMemoryProcessorStorage()

        await V2DataMigrator.migrateIfNeeded(storage: storage)

        #expect(await storage.string(forKey: "installID") == nil)
        #expect(await storage.data(forKey: "recentSessions") == nil)
    }

    @Test
    func sessionTrackingProcessorWithV2DataDoesNotFireNewInstallDetected() async throws {
        let storage = InMemoryProcessorStorage()

        let epochTimestamp = Date().addingTimeInterval(-100).timeIntervalSince1970
        await storage.set("[{\"st\":\(epochTimestamp),\"dn\":30}]".data(using: .utf8)!, forKey: "recentSessions")
        await storage.setStringArray(["2025-03-01"], forKey: "distinctDaysUsed")
        await storage.set("2025-03-01", forKey: "firstSessionDate")

        let processor = SessionTrackingProcessor()
        let emitter = CapturingEventSender()
        await processor.start(storage: storage, logger: NoOpLogger(), emitter: emitter)

        let sentEvents = await emitter.sentEvents
        let eventNames = sentEvents.map(\.name)
        #expect(!eventNames.contains(DefaultEvents.Acquisition.newInstallDetected.rawValue))

        await processor.stop()
    }

    private func decodedSessionDate(from data: Data) -> Date? {
        struct Session: Decodable {
            let startedAt: Date
            private enum CodingKeys: String, CodingKey { case startedAt = "st" }
        }
        return (try? JSONDecoder().decode([Session].self, from: data))?.first?.startedAt
    }
}
