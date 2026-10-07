import XCTest
@testable import MiniTerminal

final class CommandSafetyTests: XCTestCase {
    func testSafeCommandsDoNotRequireConfirmation() {
        XCTAssertFalse(CommandSafety.requiresConfirmation("git status"))
        XCTAssertFalse(CommandSafety.requiresConfirmation("pwd"))
        XCTAssertFalse(CommandSafety.requiresConfirmation("echo hello"))
    }

    func testDangerousCommandsRequireConfirmation() {
        XCTAssertTrue(CommandSafety.requiresConfirmation("rm -rf /tmp/example"))
        XCTAssertTrue(CommandSafety.requiresConfirmation("sudo launchctl list"))
        XCTAssertTrue(CommandSafety.requiresConfirmation("git reset --hard HEAD~1"))
        XCTAssertTrue(CommandSafety.requiresConfirmation("git clean -fd"))
    }

    func testMultilineClipboardRequiresConfirmation() {
        XCTAssertTrue(CommandSafety.requiresConfirmation("pwd\nls"))
    }
}
