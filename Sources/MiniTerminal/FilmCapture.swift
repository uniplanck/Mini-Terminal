#if FILM_CAPTURE
import AppKit
import Foundation

// Launch-film capture mode. Debug builds only (see Package.swift), and only reachable
// from the existing `--ui-fixture` branch in main.swift:
//
//   Mini-Terminal --ui-fixture --film S04 --film-fixture <film-fixture.json> [--film-autorun on|off]
//
// It configures the fixture session's isolated defaults, history and private pasteboard
// from a dataset so every take starts from the same state. It never touches the
// general pasteboard or the user's preferences.

struct FilmFixture: Decodable {
    struct Environment: Decodable {
        var appearance: String
        var language: String
        var shellPath: String
        var workingDirectory: String
        var copyOutputAfterRun: Bool
        var confirmDangerousCommands: Bool
    }

    struct HistoryItem: Decodable {
        var createdAt: Date
        var command: String
        var output: String
        var exitCode: Int32
        var duration: TimeInterval
    }

    struct Scene: Decodable {
        enum View: String, Decodable { case compact, split }

        var view: View
        var autoRun: Bool
        var panelVisibleAtLaunch: Bool
        var command: String?
        var stageClipboard: String?
        var seedHistory: Bool?
    }

    var environment: Environment
    var history: [HistoryItem]
    var scenes: [String: Scene]

    static func load(from url: URL) throws -> FilmFixture {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FilmFixture.self, from: Data(contentsOf: url))
    }

    /// History entries with IDs derived from their position, so seeded history is identical on every launch.
    var historyEntries: [HistoryEntry] {
        history.enumerated().map { index, item in
            HistoryEntry(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                createdAt: item.createdAt,
                command: item.command,
                output: item.output,
                exitCode: item.exitCode,
                duration: item.duration
            )
        }
    }
}

enum FilmCaptureError: Error, CustomStringConvertible {
    case missingFixturePath
    case unknownScene(String)
    case unknownLanguage(String)
    case invalidAutoRun(String)

    var description: String {
        switch self {
        case .missingFixturePath: return "--film requires --film-fixture <path>"
        case .unknownScene(let scene): return "film fixture has no scene \(scene)"
        case .unknownLanguage(let language): return "unknown language \(language)"
        case .invalidAutoRun(let value): return "--film-autorun expects on|off, got \(value)"
        }
    }
}

struct FilmCaptureRequest: Equatable {
    var scene: String
    var fixturePath: String?
    var autoRunOverride: Bool?

    /// Returns nil unless both `--ui-fixture` and `--film <scene>` are present,
    /// so normal launches and the plain fixture session are never affected.
    static func parse(_ arguments: [String]) throws -> FilmCaptureRequest? {
        guard arguments.contains("--ui-fixture"), let scene = value(after: "--film", in: arguments) else { return nil }
        var request = FilmCaptureRequest(scene: scene, fixturePath: value(after: "--film-fixture", in: arguments))
        if let autoRun = value(after: "--film-autorun", in: arguments) {
            switch autoRun {
            case "on": request.autoRunOverride = true
            case "off": request.autoRunOverride = false
            default: throw FilmCaptureError.invalidAutoRun(autoRun)
            }
        }
        return request
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

/// The parts of a scene that apply after AppModel exists.
struct FilmCaptureSession {
    let scene: FilmFixture.Scene
    let dark: Bool

    var panelVisibleAtLaunch: Bool { scene.panelVisibleAtLaunch }

    func configure(_ model: AppModel) {
        model.command = scene.command ?? ""
        model.isSplitView = scene.view == .split
        model.isHistoryVisible = false
    }
}

enum FilmCapture {
    /// Applies settings, history and the staged clipboard. Must run before HistoryStore and AppModel are created.
    static func prepare(
        request: FilmCaptureRequest,
        settings: SettingsStore,
        defaults: UserDefaults,
        pasteboard: NSPasteboard
    ) throws -> FilmCaptureSession {
        guard let path = request.fixturePath else { throw FilmCaptureError.missingFixturePath }
        let fixture = try FilmFixture.load(from: URL(fileURLWithPath: path))
        guard let scene = fixture.scenes[request.scene] else { throw FilmCaptureError.unknownScene(request.scene) }
        guard let language = AppLanguage(rawValue: fixture.environment.language) else {
            throw FilmCaptureError.unknownLanguage(fixture.environment.language)
        }
        precondition(pasteboard.name != NSPasteboard.general.name, "film capture must use a private pasteboard")

        settings.language = language
        settings.shellPath = fixture.environment.shellPath
        settings.workingDirectory = fixture.environment.workingDirectory
        settings.copyOutputAfterRun = fixture.environment.copyOutputAfterRun
        settings.confirmDangerousCommands = fixture.environment.confirmDangerousCommands
        let autoRun = request.autoRunOverride ?? scene.autoRun
        settings.pasteClipboardOnOpen = autoRun
        settings.autoRunAfterPaste = autoRun

        if scene.seedHistory == true {
            // Same key and encoding HistoryStore uses, written before HistoryStore reads it.
            defaults.set(try JSONEncoder().encode(fixture.historyEntries), forKey: "executionHistory")
        }

        pasteboard.clearContents()
        if let staged = scene.stageClipboard {
            pasteboard.setString(staged, forType: .string)
        }

        return FilmCaptureSession(scene: scene, dark: fixture.environment.appearance == "dark")
    }

    /// Entry point for main.swift: a broken film setup stops the launch instead of silently
    /// falling back to the plain fixture session.
    static func prepareOrExit(
        arguments: [String],
        settings: SettingsStore,
        defaults: UserDefaults,
        pasteboard: NSPasteboard
    ) -> FilmCaptureSession? {
        do {
            guard let request = try FilmCaptureRequest.parse(arguments) else { return nil }
            return try prepare(request: request, settings: settings, defaults: defaults, pasteboard: pasteboard)
        } catch {
            FileHandle.standardError.write(Data("Mini-Terminal film capture: \(error)\n".utf8))
            exit(2)
        }
    }
}
#endif
