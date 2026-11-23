import XCTest
@testable import MiniTerminal

final class ShellRunnerTests: XCTestCase {
    /// Runs a finite command and returns its displayed output and result.
    private func run(_ command: String, shellPath: String = "/bin/zsh", timeout: TimeInterval = 5) -> (output: String, result: ShellResult?) {
        let finished = expectation(description: "shell command finishes")
        var buffer = OutputBuffer()
        var result: ShellResult?
        ShellRunner().run(
            command: command,
            shellPath: shellPath,
            workingDirectory: "~",
            onOutput: { buffer.append($0) }
        ) {
            result = $0
            finished.fulfill()
        }
        wait(for: [finished], timeout: timeout)
        buffer.finish()
        return (buffer.text, result)
    }

    func testCapturesStdoutAndExitCode() {
        let (output, result) = run("printf 'mini-terminal'")
        XCTAssertEqual(output, "mini-terminal")
        XCTAssertEqual(result?.exitCode, 0)
        XCTAssertEqual(result?.wasCancelled, false)
    }

    func testCapturesStderrAndFailureExitCode() {
        let (output, result) = run("print -u2 'expected-error'; exit 7")
        XCTAssertTrue(output.contains("expected-error"))
        XCTAssertEqual(result?.exitCode, 7)
    }

    func testStdoutAndStderrKeepTheOrderTheyWereWritten() {
        XCTAssertEqual(run("echo 1; echo 2 >&2; echo 3").output, "1\n2\n3")
    }

    func testOutputArrivesWhileTheCommandIsStillRunning() {
        let early = expectation(description: "first output arrives before the command ends")
        let finished = expectation(description: "command finishes")
        var completed = false
        var received = ""
        ShellRunner().run(
            command: "printf first; sleep 1; printf second",
            shellPath: "/bin/zsh",
            workingDirectory: "~",
            onOutput: { text in
                received += text
                if received == "first" && !completed { early.fulfill() }
            }
        ) { _ in
            completed = true
            finished.fulfill()
        }
        wait(for: [early], timeout: 0.8)
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(received, "firstsecond")
    }

    func testCompletesWhenABackgroundChildKeepsThePipeOpen() {
        let started = Date()
        let (output, result) = run("sleep 5 & echo done", timeout: 2)
        XCTAssertEqual(output, "done")
        XCTAssertEqual(result?.exitCode, 0)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
    }

    func testCommandReadingStandardInputSeesEndOfFile() {
        let (output, result) = run("cat; echo after", timeout: 2)
        XCTAssertEqual(output, "after")
        XCTAssertEqual(result?.exitCode, 0)
    }

    func testMissingShellReportsTheFailure() {
        let (output, result) = run("true", shellPath: "/nonexistent/mini-terminal-shell")
        XCTAssertEqual(result?.exitCode, -1)
        XCTAssertTrue(output.contains("/nonexistent/mini-terminal-shell"))
    }

    func testSignalTerminationUsesShellExitCodeConvention() {
        XCTAssertEqual(run("kill -TERM $$").result?.exitCode, 128 + SIGTERM)
    }

    func testLargeOutputIsDeliveredCompletely() {
        let (output, result) = run("seq 1 200000", timeout: 20)
        XCTAssertEqual(result?.exitCode, 0)
        XCTAssertTrue(output.hasPrefix("1\n2\n3\n"))
        XCTAssertTrue(output.hasSuffix("\n199999\n200000"))
        XCTAssertEqual(output.utf8.count, 1_288_894)
    }

    func testUTF8DecoderHoldsACharacterSplitAcrossChunks() {
        let bytes = Array("進捗🙂".utf8)
        for split in 1..<bytes.count {
            var decoder = UTF8StreamDecoder()
            let text = decoder.decode(bytes[..<split]) + decoder.decode(bytes[split...]) + decoder.finish()
            XCTAssertEqual(text, "進捗🙂", "split at byte \(split)")
        }
    }

    func testUTF8DecoderKeepsTextAroundInvalidBytes() {
        var decoder = UTF8StreamDecoder()
        let text = decoder.decode([0x6F, 0x6B, 0xFF, 0x21]) + decoder.finish()
        XCTAssertEqual(text, "ok\u{FFFD}!")
    }
}

final class ShellCancellationTests: XCTestCase {
    private func start(_ command: String, onOutput: @escaping (String) -> Void = { _ in }) -> (ShellExecution, XCTestExpectation, () -> ShellResult?) {
        let finished = expectation(description: "command ends")
        var result: ShellResult?
        let execution = ShellRunner().run(command: command, shellPath: "/bin/zsh", workingDirectory: "/tmp", onOutput: onOutput) {
            result = $0
            finished.fulfill()
        }
        return (execution, finished, { result })
    }

    private func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

    func testCancelStopsARunningCommandPromptly() {
        let (execution, finished, result) = start("sleep 30")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let cancelledAt = Date()
        execution.cancel()
        wait(for: [finished], timeout: 2)
        XCTAssertLessThan(Date().timeIntervalSince(cancelledAt), 1)
        XCTAssertEqual(result()?.wasCancelled, true)
        XCTAssertEqual(result()?.exitCode, 128 + SIGINT)
    }

    func testCancelStopsEveryProcessInAPipeline() {
        let reported = expectation(description: "child pids reported")
        var text = ""
        var didReport = false
        let (execution, finished, _) = start("(sleep 30 & echo $!; wait) | cat; sleep 30") { chunk in
            text += chunk
            if text.contains("\n") && !didReport { didReport = true; reported.fulfill() }
        }
        wait(for: [reported], timeout: 3)
        let child = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))!
        XCTAssertTrue(isAlive(child))

        execution.cancel()
        wait(for: [finished], timeout: 3)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(isAlive(child), "the pipeline's background sleep must not outlive the stop request")
    }

    func testCancelEscalatesWhenTheCommandIgnoresInterrupts() {
        let (execution, finished, result) = start("trap '' INT TERM; sleep 30")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let cancelledAt = Date()
        execution.cancel()
        wait(for: [finished], timeout: 8)
        XCTAssertGreaterThan(Date().timeIntervalSince(cancelledAt), 3)
        XCTAssertEqual(result()?.exitCode, 128 + SIGKILL)
    }

    func testSecondCancelForcesTheStopImmediately() {
        let (execution, finished, result) = start("trap '' INT TERM; sleep 30")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        execution.cancel()
        execution.cancel()
        wait(for: [finished], timeout: 1.5)
        XCTAssertEqual(result()?.exitCode, 128 + SIGKILL)
    }

    func testTerminateEndsTheCommandForAppQuit() {
        let (execution, finished, result) = start("sleep 30")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        execution.terminate()
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(result()?.exitCode, 128 + SIGTERM)
        XCTAssertEqual(result()?.wasCancelled, true)
    }

    func testCancelAfterCompletionIsHarmless() {
        let (execution, finished, result) = start("true")
        wait(for: [finished], timeout: 3)
        execution.cancel()
        XCTAssertEqual(result()?.exitCode, 0)
        XCTAssertEqual(result()?.wasCancelled, false)
    }
}
