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

    /// Stored output per entry, in UTF-8 bytes. History is decoded at launch and
    /// rewritten after every run, so it must stay small.
    static let maximumStoredOutput = 20_000
    static let omissionMarker = "[…]\n"

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
            output: Self.boundedOutput(output),
            exitCode: exitCode,
            duration: duration
        )

        entries.insert(entry, at: 0)
        if entries.count > maximumEntries {
            entries.removeLast(entries.count - maximumEntries)
        }
        persist()
    }

    /// Keeps the end of long output, where the result or the error usually is.
    static func boundedOutput(_ output: String) -> String {
        let utf8 = output.utf8
        guard utf8.count > maximumStoredOutput else { return output }
        var cut = utf8.index(utf8.startIndex, offsetBy: utf8.count - maximumStoredOutput)
        if let newline = utf8[cut...].firstIndex(of: 0x0A), utf8.index(after: newline) != utf8.endIndex {
            cut = utf8.index(after: newline)
        } else {
            while utf8[cut] & 0xC0 == 0x80 { cut = utf8.index(after: cut) }
        }
        return omissionMarker + String(output[cut...])
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
