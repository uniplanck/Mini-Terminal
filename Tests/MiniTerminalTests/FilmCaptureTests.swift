#if FILM_CAPTURE
import AppKit
import Combine
import XCTest
@testable import MiniTerminal

final class FilmCaptureTests: XCTestCase {
    private let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("launch-video/assets/ui/fixtures/film-fixture.json")

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        suiteName = "MiniTerminalTests.Film.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminalTests.Film.\(UUID().uuidString)"))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        pasteboard.releaseGlobally()
        super.tearDown()
    }

    private func prepare(_ scene: String, autoRun: Bool? = nil) throws -> (SettingsStore, FilmCaptureSession) {
        let settings = SettingsStore(defaults: defaults)
        let request = FilmCaptureRequest(scene: scene, fixturePath: fixtureURL.path, autoRunOverride: autoRun)
        return (settings, try FilmCapture.prepare(request: request, settings: settings, defaults: defaults, pasteboard: pasteboard))
    }

    func testFilmArgumentsAreIgnoredOutsideFixtureMode() throws {
        XCTAssertNil(try FilmCaptureRequest.parse(["Mini-Terminal"]))
        XCTAssertNil(try FilmCaptureRequest.parse(["Mini-Terminal", "--ui-fixture"]))
        XCTAssertNil(try FilmCaptureRequest.parse(["Mini-Terminal", "--ui-fixture", "--dark"]))
        XCTAssertNil(try FilmCaptureRequest.parse(["Mini-Terminal", "--film", "S04", "--film-fixture", "f.json"]))
    }

    func testFilmArgumentsParse() throws {
        XCTAssertEqual(
            try FilmCaptureRequest.parse(["x", "--ui-fixture", "--film", "S04", "--film-fixture", "/tmp/f.json", "--film-autorun", "off"]),
            FilmCaptureRequest(scene: "S04", fixturePath: "/tmp/f.json", autoRunOverride: false)
        )
        XCTAssertThrowsError(try FilmCaptureRequest.parse(["x", "--ui-fixture", "--film", "S04", "--film-autorun", "maybe"]))
    }

    func testRepositoryFixtureDecodesEveryPlannedScene() throws {
        let fixture = try FilmFixture.load(from: fixtureURL)
        XCTAssertEqual(Set(fixture.scenes.keys), ["S03", "S04", "S05", "S06", "S08"])
        XCTAssertEqual(fixture.history.count, 9)
        XCTAssertEqual(fixture.environment.language, AppLanguage.ja.rawValue)
        XCTAssertTrue(fixture.environment.workingDirectory.hasPrefix("/tmp/mini-terminal-film/"))
    }

    func testClipboardSceneAppliesJapaneseAutoRunAndStagesPrivatePasteboardOnly() throws {
        let generalChangeCount = NSPasteboard.general.changeCount
        let (settings, session) = try prepare("S04")

        XCTAssertEqual(settings.language, .ja)
        XCTAssertTrue(settings.pasteClipboardOnOpen)
        XCTAssertTrue(settings.autoRunAfterPaste)
        XCTAssertTrue(settings.copyOutputAfterRun)
        XCTAssertTrue(settings.confirmDangerousCommands)
        XCTAssertFalse(session.panelVisibleAtLaunch)
        XCTAssertTrue(session.dark)
        XCTAssertEqual(pasteboard.string(forType: .string), "date -u -r 1790000000 '+%Y-%m-%d %H:%M UTC'")
        XCTAssertEqual(NSPasteboard.general.changeCount, generalChangeCount)
    }

    func testAutoRunOverrideTurnsClipboardAutomationOff() throws {
        let (settings, _) = try prepare("S04", autoRun: false)
        XCTAssertFalse(settings.pasteClipboardOnOpen)
        XCTAssertFalse(settings.autoRunAfterPaste)
    }

    func testHistorySceneSeedsIdenticalHistoryOnEveryLaunch() throws {
        _ = try prepare("S06")
        let first = HistoryStore(defaults: defaults).entries
        XCTAssertEqual(first.count, 9)
        XCTAssertEqual(first.first?.command, "git status --short")
        XCTAssertEqual(first.first?.createdAt, ISO8601DateFormatter().date(from: "2026-10-08T09:24:00+09:00"))
        XCTAssertEqual(first.filter { $0.exitCode != 0 }.map(\.command), ["lsof -i :8080"])

        defaults.removePersistentDomain(forName: suiteName)
        _ = try prepare("S06")
        XCTAssertEqual(HistoryStore(defaults: defaults).entries, first)
    }

    func testScenesWithoutSeedStartWithEmptyHistoryAndConfigureModel() throws {
        let (settings, session) = try prepare("S05")
        let model = AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard)
        model.isSplitView = true
        session.configure(model)

        XCTAssertTrue(model.historyStore.entries.isEmpty)
        XCTAssertEqual(model.command, "wc -l Sources/MiniTerminal/*.swift")
        XCTAssertFalse(model.isSplitView)
        XCTAssertTrue(session.panelVisibleAtLaunch)
        XCTAssertNil(pasteboard.string(forType: .string))
    }

    func testDangerousSceneCommandStillRequiresConfirmation() {
        XCTAssertTrue(CommandSafety.requiresConfirmation("rm -rf ./build"))
    }

    func testUnknownSceneAndMissingFixtureFail() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertThrowsError(try FilmCapture.prepare(request: FilmCaptureRequest(scene: "S99", fixturePath: fixtureURL.path),
                                                     settings: settings, defaults: defaults, pasteboard: pasteboard))
        XCTAssertThrowsError(try FilmCapture.prepare(request: FilmCaptureRequest(scene: "S04", fixturePath: nil),
                                                     settings: settings, defaults: defaults, pasteboard: pasteboard))
    }

    func testClipboardSceneRunsStagedCommandAndCopiesOutput() throws {
        let (settings, session) = try prepare("S04")
        settings.workingDirectory = NSTemporaryDirectory() // the film workspace is not required for this command
        let model = AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard)
        session.configure(model)

        let finished = expectation(description: "staged clipboard command runs")
        var cancellable: AnyCancellable?
        cancellable = model.$exitCode.compactMap { $0 }.sink { code in
            XCTAssertEqual(code, 0)
            XCTAssertEqual(model.output.trimmingCharacters(in: .whitespacesAndNewlines), "2026-09-21 14:13 UTC")
            XCTAssertEqual(self.pasteboard.string(forType: .string), model.output)
            finished.fulfill()
        }
        model.prepareForPresentation()
        wait(for: [finished], timeout: 5)
        withExtendedLifetime(cancellable) {}
    }
}
#endif
