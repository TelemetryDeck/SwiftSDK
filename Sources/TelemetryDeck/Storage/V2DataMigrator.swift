import Foundation

/// Migrates persisted data from the v2 SDK format into the v3 format.
///
/// v2 encoded session dates as seconds since the Unix epoch (1970-01-01) while v3 uses Swift's
/// default `JSONEncoder`, which encodes dates as seconds since the reference date (2001-01-01).
/// v2 also stored `distinctDaysUsed` as a plist string array while v3 stores a JSON-encoded `Set<String>`.
/// Finally, v2 had no `installID` key; its absence causes v3 to fire a false `newInstallDetected` event.
///
/// Migration is idempotent: once `installID` is set the migrator does nothing on subsequent launches.
enum V2DataMigrator {
    private struct V2Session: Decodable {
        let startedAt: Date
        let durationInSeconds: Int

        private enum CodingKeys: String, CodingKey {
            case startedAt = "st"
            case durationInSeconds = "dn"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let epochSeconds = try container.decode(Double.self, forKey: .startedAt)
            self.startedAt = Date(timeIntervalSince1970: epochSeconds)
            self.durationInSeconds = try container.decode(Int.self, forKey: .durationInSeconds)
        }
    }

    private struct V3Session: Encodable {
        let startedAt: Date
        let durationInSeconds: Int

        private enum CodingKeys: String, CodingKey {
            case startedAt = "st"
            case durationInSeconds = "dn"
        }
    }

    static func migrateIfNeeded(storage: any ProcessorStorage) async {
        let existingInstallID = await storage.string(forKey: "installID")
        guard existingInstallID == nil else { return }

        var didMigrateAnything = false

        if let rawData = await storage.data(forKey: "recentSessions"),
            let v2Sessions = try? JSONDecoder().decode([V2Session].self, from: rawData)
        {
            let v3Sessions = v2Sessions.map { V3Session(startedAt: $0.startedAt, durationInSeconds: $0.durationInSeconds) }
            if let v3Data = try? JSONEncoder().encode(v3Sessions) {
                await storage.set(v3Data, forKey: "recentSessions")
                didMigrateAnything = true
            }
        }

        if let days = await storage.stringArray(forKey: "distinctDaysUsed") {
            let daysSet = Set(days)
            if let daysData = try? JSONEncoder().encode(daysSet) {
                await storage.set(daysData, forKey: "distinctDaysUsed")
                didMigrateAnything = true
            }
        }

        let hasFirstSessionDate = await storage.string(forKey: "firstSessionDate") != nil
        if didMigrateAnything || hasFirstSessionDate {
            await storage.set(UUID().uuidString, forKey: "installID")
        }
    }
}
