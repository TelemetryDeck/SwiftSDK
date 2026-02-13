import Foundation
import Testing

@testable import TelemetryDeck

@Suite(.serialized)
struct EventCacheTests {
    @Test
    func defaultCacheAddsEventsAndIncreasesCount() async {
        let cache = DefaultEventCache()
        let event = createTestEvent()

        await cache.add(event)
        let count = await cache.count()
        #expect(count == 1)

        await cache.add(event)
        let newCount = await cache.count()
        #expect(newCount == 2)
    }

    @Test
    func defaultCachePopReturnsBatchOf100Max() async {
        let cache = DefaultEventCache()
        for _ in 0..<150 {
            await cache.add(createTestEvent())
        }

        let batch1 = await cache.pop()
        #expect(batch1.count == 100)

        let remainingCount = await cache.count()
        #expect(remainingCount == 50)

        let batch2 = await cache.pop()
        #expect(batch2.count == 50)

        let finalCount = await cache.count()
        #expect(finalCount == 0)
    }

    @Test
    func defaultCachePopClearsPoppedEvents() async {
        let cache = DefaultEventCache()
        await cache.add(createTestEvent())
        await cache.add(createTestEvent())

        let initialCount = await cache.count()
        #expect(initialCount == 2)

        let popped = await cache.pop()
        #expect(popped.count == 2)

        let afterPopCount = await cache.count()
        #expect(afterPopCount == 0)
    }

    @Test
    func inMemoryCacheReturnsAllEventsInOnePop() async {
        let cache = InMemoryEventCache()
        for _ in 0..<150 {
            await cache.add(createTestEvent())
        }

        let all = await cache.pop()
        #expect(all.count == 150)

        let afterCount = await cache.count()
        #expect(afterCount == 0)
    }

    @Test
    func defaultCachePersistAndRestoreRoundtrip() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test-cache-\(UUID().uuidString).json")

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        let event1 = createTestEvent(type: "Signal.one")
        let event2 = createTestEvent(type: "Signal.two")

        let events = [event1, event2]
        guard let data = try? JSONEncoder.telemetryEncoder.encode(events) else {
            Issue.record("Failed to encode events")
            return
        }

        do {
            try data.write(to: testFileURL)
        } catch {
            Issue.record("Failed to write file: \(error)")
            return
        }

        #expect(FileManager.default.fileExists(atPath: testFileURL.path))

        guard let readData = try? Data(contentsOf: testFileURL),
            let decoded = try? JSONDecoder.telemetryDecoder.decode([Event].self, from: readData)
        else {
            Issue.record("Failed to read and decode file")
            return
        }

        #expect(decoded.count == 2)
        #expect(decoded[0].type == "Signal.one")
        #expect(decoded[1].type == "Signal.two")
    }

    @Test
    func manualPersistWorks() async {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesURL.appendingPathComponent("test-manual-persist.json")

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let event = createTestEvent()
        let data = try? JSONEncoder.telemetryEncoder.encode([event])
        #expect(data != nil)

        do {
            try data?.write(to: fileURL)
        } catch {
            Issue.record("Failed to write: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func restorePrependsPersistedEventsBeforeInMemory() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-restore-merge-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let writerCache = DefaultEventCache(fileURL: fileURL)
        await writerCache.add(createTestEvent(type: "Signal.B"))
        await writerCache.add(createTestEvent(type: "Signal.C"))
        await writerCache.persist()

        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let cache = DefaultEventCache(fileURL: fileURL)
        await cache.add(createTestEvent(type: "Signal.A"))
        #expect(await cache.count() == 1)

        await cache.restore()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(await cache.count() == 3)

        let popped = await cache.pop()
        #expect(popped.count == 3)
        #expect(popped[0].type == "Signal.B")
        #expect(popped[1].type == "Signal.C")
        #expect(popped[2].type == "Signal.A")
    }

    @Test
    func persistCreatesFileOnDisk() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-persist-creates-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cache = DefaultEventCache(fileURL: fileURL)
        await cache.add(createTestEvent())
        await cache.persist()

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func restoreWithNoFilePreservesInMemoryEvents() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-no-file-\(UUID().uuidString).json")

        let cache = DefaultEventCache(fileURL: fileURL)

        let eventA = createTestEvent(type: "Signal.A")
        let eventB = createTestEvent(type: "Signal.B")
        await cache.add(eventA)
        await cache.add(eventB)

        let initialCount = await cache.count()
        #expect(initialCount == 2)

        await cache.restore()

        let countAfterRestore = await cache.count()
        #expect(countAfterRestore == 2)

        let popped = await cache.pop()
        #expect(popped.count == 2)
        #expect(popped[0].type == "Signal.A")
        #expect(popped[1].type == "Signal.B")
    }

    private func createTestEvent(type: String = "Test.signal") -> Event {
        Event(
            appID: "test-app",
            type: type,
            clientUser: "test-user-hash",
            sessionID: UUID().uuidString,
            receivedAt: Date(),
            payload: ["test": "data"],
            floatValue: nil,
            isTestMode: true
        )
    }
}
