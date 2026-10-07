import XCTest
@testable import MiniTerminal

final class ShellRunnerTests: XCTestCase {
    func testCapturesStdoutAndExitCode() {
        let expectation = expectation(description: "shell command finishes")
        let runner = ShellRunner()

        runner.run(
            command: "printf 'mini-terminal'",
            shellPath: "/bin/zsh",
            workingDirectory: "~"
        ) { result in
            XCTAssertEqual(result.stdout, "mini-terminal")
            XCTAssertEqual(result.stderr, "")
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(result.combinedOutput, "mini-terminal")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    func testCapturesStderrAndFailureExitCode() {
        let expectation = expectation(description: "failing shell command finishes")
        let runner = ShellRunner()

        runner.run(
            command: "print -u2 'expected-error'; exit 7",
            shellPath: "/bin/zsh",
            workingDirectory: "~"
        ) { result in
            XCTAssertTrue(result.stderr.contains("expected-error"))
            XCTAssertEqual(result.exitCode, 7)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }
}
