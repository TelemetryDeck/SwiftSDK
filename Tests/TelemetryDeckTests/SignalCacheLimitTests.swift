import Foundation
import Testing

@testable import TelemetryDeck

struct SignalCacheLimitTests {

    @Test
    func pushSingleSignals_dropsOldestWhenLimitExceeded() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cache = SignalCache<String>(logHandler: nil, cacheLimit: 5, fileURL: tmp)
        for i in 0..<7 {
            cache.push("\(i)")
        }

        #expect(cache.count() == 5)

        let popped = cache.pop()
        #expect(popped == ["2", "3", "4", "5", "6"])
    }

    @Test
    func pushBatchOfSignals_dropsOldestWhenLimitExceeded() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let cache = SignalCache<String>(logHandler: nil, cacheLimit: 5, fileURL: tmp)
        cache.push(["0", "1", "2", "3", "4", "5", "6"])

        #expect(cache.count() == 5)

        let popped = cache.pop()
        #expect(popped == ["2", "3", "4", "5", "6"])
    }

    @Test
    func reloadFromDisk_mergesWithInMemorySignals() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let writer = SignalCache<String>(logHandler: nil, cacheLimit: 100, fileURL: tmp)
        writer.push(["a", "b", "c"])
        writer.backupCache()

        let tmp2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp2) }

        let cache = SignalCache<String>(logHandler: nil, cacheLimit: 100, fileURL: tmp2)
        cache.push(["d", "e"])

        let diskData = try JSONEncoder().encode(["a", "b", "c"])
        try diskData.write(to: tmp2)

        cache.reloadFromDisk()

        #expect(cache.count() == 5)

        let popped = cache.pop()
        #expect(Set(popped) == Set(["a", "b", "c", "d", "e"]))
    }

    @Test
    func restoreFromDisk_trimsToLimit() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let writer = SignalCache<String>(logHandler: nil, cacheLimit: 10_000, fileURL: tmp)
        for i in 0..<10 {
            writer.push("\(i)")
        }
        writer.backupCache()

        let reader = SignalCache<String>(logHandler: nil, cacheLimit: 5, fileURL: tmp)
        #expect(reader.count() == 5)

        let popped = reader.pop()
        #expect(popped == ["5", "6", "7", "8", "9"])
    }
}
