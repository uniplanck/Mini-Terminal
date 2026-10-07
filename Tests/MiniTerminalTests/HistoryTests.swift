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

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminalTests.Feedback.\(UUID().uuidString)"))
        let model = AppModel(
            settings: settings,
            historyStore: HistoryStore(defaults: defaults),
            pasteboard: pasteboard
        )
        model.command = "copy me"
        model.copyInput()

        XCTAssertEqual(model.copyFeedback, "入力をコピーしました")
        XCTAssertEqual(pasteboard.string(forType: .string), "copy me")

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

    func testHistoryRecallCursorResetsAfterHistoryIsCleared() {
        let suiteName = "MiniTerminalTests.HistoryClearCursor.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let history = HistoryStore(defaults: defaults)
        history.add(command: "old command", output: "old result", exitCode: 0, duration: 0.01)
        let model = AppModel(settings: SettingsStore(defaults: defaults), historyStore: history)
        model.command = "draft"
        model.recallPreviousCommand()
        history.clear()
        model.recallPreviousCommand()

        XCTAssertEqual(model.command, "draft")
        model.recallNextCommand()
        XCTAssertEqual(model.command, "draft")
    }

    func testHistoryRestoreIsIgnoredWhileCommandIsRunning() {
        let suiteName = "MiniTerminalTests.HistoryRestoreRunning.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let history = HistoryStore(defaults: defaults)
        let entry = HistoryEntry(id: UUID(), createdAt: Date(), command: "old", output: "result", exitCode: 0, duration: 0.1)
        let model = AppModel(settings: SettingsStore(defaults: defaults), historyStore: history)
        model.command = "current draft"
        model.output = "current output"
        model.isRunning = true

        model.restoreHistory(entry)

        XCTAssertEqual(model.command, "current draft")
        XCTAssertEqual(model.output, "current output")
        XCTAssertTrue(model.isRunning)
    }
}
