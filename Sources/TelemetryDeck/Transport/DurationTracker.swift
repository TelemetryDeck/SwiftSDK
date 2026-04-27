import Foundation

actor DurationTracker: DurationTracking {
    private struct ActiveDuration: Codable {
        let startDate: Date
        let parameters: [String: PayloadValue]
        let includeBackgroundTime: Bool
    }

    private var activeDurations: [String: ActiveDuration] = [:]
    private var lastEnteredBackground: Date?
    private var storage: (any ProcessorStorage)?
    private var lifecycleTask: Task<Void, Never>?
    private let dateProvider: DateProvider

    private static let storageKey = "durationTrackerState"

    init(dateProvider: DateProvider = .system) {
        self.dateProvider = dateProvider
    }

    func start(storage: any ProcessorStorage) async {
        self.storage = storage
        await restoreState()
        lifecycleTask = Task {
            for await event in LifecycleNotifier.events() {
                switch event {
                case .background:
                    handleBackground()
                case .foreground:
                    handleForeground()
                case .termination:
                    break
                }
            }
        }
    }

    func stop() async {
        lifecycleTask?.cancel()
        lifecycleTask = nil
    }

    func handleBackground() {
        lastEnteredBackground = dateProvider.now()
    }

    func handleForeground() {
        guard let backgroundDate = lastEnteredBackground else { return }
        let backgroundDuration = dateProvider.now().timeIntervalSince(backgroundDate)
        lastEnteredBackground = nil

        for (name, duration) in activeDurations where !duration.includeBackgroundTime {
            activeDurations[name] = ActiveDuration(
                startDate: duration.startDate.addingTimeInterval(backgroundDuration),
                parameters: duration.parameters,
                includeBackgroundTime: duration.includeBackgroundTime
            )
        }
    }

    func startDuration(
        _ eventName: String,
        parameters: EventParameters,
        includeBackgroundTime: Bool
    ) {
        activeDurations[eventName] = ActiveDuration(
            startDate: dateProvider.now(),
            parameters: parameters.payloadDictionary,
            includeBackgroundTime: includeBackgroundTime
        )
        Task { await persistState() }
    }

    func stopDuration(_ eventName: String) -> DurationResult? {
        guard let duration = activeDurations.removeValue(forKey: eventName) else {
            return nil
        }
        Task { await persistState() }
        let elapsed = dateProvider.now().timeIntervalSince(duration.startDate)
        return DurationResult(
            durationInSeconds: elapsed,
            startParameters: EventParameters(duration.parameters)
        )
    }

    func cancelDuration(_ eventName: String) {
        activeDurations.removeValue(forKey: eventName)
        Task { await persistState() }
    }

    private func persistState() async {
        guard let storage else { return }
        guard let data = try? JSONEncoder().encode(activeDurations) else { return }
        await storage.set(data, forKey: Self.storageKey)
    }

    private func restoreState() async {
        guard let storage else { return }
        guard let data = await storage.data(forKey: Self.storageKey),
            let restored = try? JSONDecoder().decode([String: ActiveDuration].self, from: data)
        else {
            return
        }
        activeDurations = restored
    }
}
