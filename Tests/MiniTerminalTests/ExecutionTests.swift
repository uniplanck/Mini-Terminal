import AppKit
import Combine
import XCTest
@testable import MiniTerminal

final class ExecutionTests: XCTestCase {
    private func withFixture(_ body: (AppModel, NSPasteboard) -> Void) {
        let suite = "MiniTerminalTests.Execution.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.language = .en
        settings.shellPath = "/bin/zsh"
        settings.workingDirectory = "/tmp"
        let pasteboard = NSPasteboard(name: .init(suite))
        pasteboard.clearContents()
        body(AppModel(settings: settings, historyStore: HistoryStore(defaults: defaults), pasteboard: pasteboard), pasteboard)
        pasteboard.releaseGlobally()
    }

    private func waitForExit(_ model: AppModel, timeout: TimeInterval = 5) {
        let finished = expectation(description: "command finishes")
        let subscription = model.$exitCode.compactMap { $0 }.first().sink { _ in finished.fulfill() }
        wait(for: [finished], timeout: timeout)
        withExtendedLifetime(subscription) {}
    }

    private func waitForOutput(_ model: AppModel, containing text: String, timeout: TimeInterval = 3) {
        let seen = expectation(description: "output contains \(text)")
        let subscription = model.$outputBuffer.filter { $0.text.contains(text) }.first().sink { _ in seen.fulfill() }
        wait(for: [seen], timeout: timeout)
        withExtendedLifetime(subscription) {}
    }

    func testOutputReachesTheModelBeforeTheCommandEnds() {
        withFixture { model, _ in
            model.command = "printf 'frame=1\\r'; sleep 0.2; printf 'frame=2\\r'; sleep 1; echo; echo finished"
            model.execute()
            waitForOutput(model, containing: "frame=2")
            XCTAssertTrue(model.isRunning)
            XCTAssertNil(model.exitCode)
            XCTAssertEqual(model.output, "frame=2")
            waitForExit(model)
            XCTAssertEqual(model.output, "frame=2\nfinished")
            XCTAssertEqual(model.historyStore.entries.first?.output, "frame=2\nfinished")
        }
    }

    func testFloodOfOutputStaysWithinTheDisplayLimit() {
        withFixture { model, pasteboard in
            model.command = "yes 'mini-terminal flood line' | head -c 6000000"
            model.execute()
            waitForExit(model, timeout: 30)
            XCTAssertEqual(model.exitCode, 0)
            XCTAssertTrue(model.outputBuffer.isTruncated)
            XCTAssertLessThanOrEqual(model.output.utf8.count, OutputBuffer.defaultLimit)
            XCTAssertTrue(model.output.hasPrefix("mini-terminal flood line\n"))
            XCTAssertEqual(pasteboard.string(forType: .string), model.output)
        }
    }
}
