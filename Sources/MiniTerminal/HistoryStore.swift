import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let command: String
    let output: String
    let exitCode: Int32
    let duration: TimeInterval
}

final class HistoryStore: ObservableObject {
    private enum Keys {
        static let entries = "executionHistory"
    }

    private let defaults: UserDefaults
    private let maximumEntries: Int

    @Published private(set) var entries: [HistoryEntry]

    init(defaults: UserDefaults = .standard, maximumEntries: Int = 100) {
        self.defaults = defaults
        self.maximumEntries = maximumEntries

        if let data = defaults.data(forKey: Keys.entries),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = Array(decoded.prefix(maximumEntries))
        } else {
            entries = []
        }
    }

    func add(command: String, output: String, exitCode: Int32, duration: TimeInterval) {
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            command: command,
            output: output,
            exitCode: exitCode,
            duration: duration
        )

        entries.insert(entry, at: 0)
        if entries.count > maximumEntries {
            entries.removeLast(entries.count - maximumEntries)
        }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Keys.entries)
        }
    }
}
