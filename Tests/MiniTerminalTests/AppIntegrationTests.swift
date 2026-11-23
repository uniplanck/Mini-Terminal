import AppKit
import Combine
import XCTest
@testable import MiniTerminal

final class AppIntegrationTests: XCTestCase {
    func testGlobalHotKeyRegistrationAcceptsValidShortcut() {
        _ = NSApplication.shared
        let manager = HotKeyManager()
        let shortcut = Shortcut(
            keyCode: 49,
            modifierFlagsRawValue: NSEvent.ModifierFlags([.control, .option, .shift]).rawValue,
            keyLabel: "Space"
        )

        XCTAssertTrue(manager.register(shortcut))
    }

    func testAutoPasteRunAndOutputCopyFlow() {
        let suiteName = "MiniTerminalTests.AutoRun.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.pasteClipboardOnOpen = true
        settings.autoRunAfterPaste = true
        settings.copyOutputAfterRun = true
        settings.confirmDangerousCommands = true
        settings.shellPath = "/bin/zsh"
        settings.workingDirectory = "~"

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminalTests.AutoRun.\(UUID().uuidString)"))
        let model = AppModel(
            settings: settings,
            historyStore: HistoryStore(defaults: defaults),
            pasteboard: pasteboard
        )
        pasteboard.clearContents()
        pasteboard.setString("printf 'auto-output'", forType: .string)

        let finished = expectation(description: "auto-run completes")
        var cancellable: AnyCancellable?
        cancellable = model.$exitCode
            .compactMap { $0 }
            .sink { code in
                XCTAssertEqual(code, 0)
                XCTAssertEqual(model.output, "auto-output")
                XCTAssertEqual(pasteboard.string(forType: .string), "auto-output")
                finished.fulfill()
            }

        model.prepareForPresentation()
        wait(for: [finished], timeout: 5)
        withExtendedLifetime(cancellable) {}
    }

    func testClipboardPasteOnPresentationAndCopyHelpers() {
        let suiteName = "MiniTerminalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.pasteClipboardOnOpen = true
        settings.autoRunAfterPaste = false

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniTerminalTests.Paste.\(UUID().uuidString)"))
        let model = AppModel(
            settings: settings,
            historyStore: HistoryStore(defaults: defaults),
            pasteboard: pasteboard
        )
        pasteboard.clearContents()
        pasteboard.setString("echo clipboard", forType: .string)

        model.prepareForPresentation()
        XCTAssertEqual(model.command, "echo clipboard")

        model.command = "pwd"
        model.copyInput()
        XCTAssertEqual(pasteboard.string(forType: .string), "pwd")
    }
}
