import AppKit
import XCTest
@testable import MiniTerminal

final class HistoryTests: XCTestCase {
    func testHistoryPersistsAndKeepsNewestFirst() {
        let suiteName = "MiniTerminalTests.History.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = HistoryStore(defaults: defaults)
        store.add(command: "pwd", output: "/tmp", exitCode: 0, duration: 0.01)
        store.add(command: "echo newest", output: "newest", exitCode: 0, duration: 0.02)

        XCTAssertEqual(store.entries.map(\.command), ["echo newest", "pwd"])

        let reloaded = HistoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.entries.map(\.command), ["echo newest", "pwd"])
        XCTAssertEqual(reloaded.entries.first?.output, "newest")
    }

    func testArrowStyleHistoryRecallRestoresDraft() {
        let suiteName = "MiniTerminalTests.HistoryRecall.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let history = HistoryStore(defaults: defaults)
        history.add(command: "first", output: "", exitCode: 0, duration: 0.01)
        history.add(command: "second", output: "", exitCode: 0, duration: 0.01)

        let model = AppModel(
            settings: SettingsStore(defaults: defaults),
            historyStore: history
        )
        model.command = "draft"

        model.recallPreviousCommand()
        XCTAssertEqual(model.command, "second")

        model.recallPreviousCommand()
        XCTAssertEqual(model.command, "first")

        model.recallNextCommand()
        XCTAssertEqual(model.command, "second")

        model.recallNextCommand()
        XCTAssertEqual(model.command, "draft")
    }

    func testCopyFeedbackAppearsAndClearsAfterAboutOneSecond() {
        let suiteName = "MiniTerminalTests.CopyFeedback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.language = .ja

        let model = AppModel(
            settings: settings,
            historyStore: HistoryStore(defaults: defaults)
        )
        model.command = "copy me"
        model.copyInput()

        XCTAssertEqual(model.copyFeedback, "入力をコピーしました")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "copy me")

        let cleared = expectation(description: "copy feedback clears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            XCTAssertNil(model.copyFeedback)
            cleared.fulfill()
        }

        wait(for: [cleared], timeout: 2)
    }

    func testLaunchAutoRunToggleEnablesClipboardPaste() {
        let suiteName = "MiniTerminalTests.AutoRunToggle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.pasteClipboardOnOpen = false
        settings.autoRunAfterPaste = false

        let model = AppModel(
            settings: settings,
            historyStore: HistoryStore(defaults: defaults)
        )

        model.toggleLaunchAutoRun()
        XCTAssertTrue(settings.pasteClipboardOnOpen)
        XCTAssertTrue(settings.autoRunAfterPaste)

        model.toggleLaunchAutoRun()
        XCTAssertFalse(settings.autoRunAfterPaste)
    }
}
