import AppKit
import Combine
import XCTest
@testable import MiniTerminal

final class ClipboardRegressionTests: XCTestCase {
    private func withFixture(_ body: (AppModel, NSPasteboard) -> Void) {
        let suite = "MiniTerminalTests.ClipboardRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.language = .en
        settings.shellPath = "/bin/zsh"
        settings.workingDirectory = "/tmp"
        let pasteboard = NSPasteboard(name: .init(suite))
        body(AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard), pasteboard)
        pasteboard.releaseGlobally()
    }

    private func waitForRun(_ model: AppModel, start: () -> Void) {
        let finished = expectation(description: "finite fixture command finishes")
        let subscription = model.$exitCode.compactMap { $0 }.first().sink { _ in finished.fulfill() }
        start()
        wait(for: [finished], timeout: 5)
        withExtendedLifetime(subscription) {}
    }

    func testReopeningDoesNotExecuteAppProducedOutput() {
        withFixture { model, pasteboard in
            model.settings.autoRunAfterPaste = true
            pasteboard.setString("printf 'this-is-output-not-a-command'", forType: .string)
            waitForRun(model) { model.prepareForPresentation() }
            XCTAssertEqual(model.historyStore.entries.count, 1)
            XCTAssertEqual(pasteboard.string(forType: .string), "this-is-output-not-a-command")
            model.prepareForPresentation()
            XCTAssertFalse(model.isRunning)
            XCTAssertEqual(model.historyStore.entries.count, 1)
            XCTAssertEqual(model.command, "printf 'this-is-output-not-a-command'")
        }
    }

    func testPresentationPreservesRunningCommand() {
        withFixture { model, pasteboard in
            model.command = "current command"
            model.isRunning = true
            pasteboard.setString("different command", forType: .string)
            model.prepareForPresentation()
            XCTAssertEqual(model.command, "current command")
        }
    }

    func testNoOutputDoesNotEraseClipboardAutomatically() {
        withFixture { model, pasteboard in
            pasteboard.setString("keep this fixture", forType: .string)
            model.command = ":"
            waitForRun(model) { model.execute() }
            XCTAssertEqual(pasteboard.string(forType: .string), "keep this fixture")
            XCTAssertEqual(model.output, "")
        }
    }

    func testCombinedCopyPairsOutputWithItsExecutedCommand() {
        withFixture { model, pasteboard in
            model.command = "printf 'matched-result'"
            waitForRun(model) { model.execute() }
            model.command = "unexecuted draft"
            model.copyInputAndOutput()
            XCTAssertEqual(pasteboard.string(forType: .string), "INPUT\nprintf 'matched-result'\n\nOUTPUT\nmatched-result")
        }
    }

    func testEnablingAutoRunRepairsDisabledPaste() {
        withFixture { model, _ in
            model.settings.pasteClipboardOnOpen = false
            model.settings.autoRunAfterPaste = true
            model.toggleLaunchAutoRun()
            XCTAssertTrue(model.settings.pasteClipboardOnOpen)
            XCTAssertTrue(model.settings.autoRunAfterPaste)
        }
    }

    func testLayoutsShareOneSizingFunction() {
        XCTAssertEqual(UIParameters.launcherSize(split: false, history: false), CGSize(width: 720, height: 96))
        XCTAssertEqual(UIParameters.launcherSize(split: true, history: false), CGSize(width: 900, height: 480))
        XCTAssertEqual(UIParameters.launcherSize(split: true, history: true), CGSize(width: 900, height: 416))
        XCTAssertEqual(UIParameters.launcherSize(split: true, history: false, available: CGSize(width: 672, height: 500)), CGSize(width: 640, height: 468))
    }
}
