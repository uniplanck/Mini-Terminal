import Foundation

struct ShellResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval

    var combinedOutput: String {
        let out = stdout.trimmingCharacters(in: .newlines)
        let err = stderr.trimmingCharacters(in: .newlines)
        switch (out.isEmpty, err.isEmpty) {
        case (false, false): return out + "\n" + err
        case (false, true): return out
        case (true, false): return err
        case (true, true): return ""
        }
    }
}

final class ShellRunner {
    func run(
        command: String,
        shellPath: String,
        workingDirectory: String,
        completion: @escaping (ShellResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let startedAt = Date()
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-lc", command]
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let expandedWorkingDirectory = NSString(string: workingDirectory).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedWorkingDirectory) {
                process.currentDirectoryURL = URL(fileURLWithPath: expandedWorkingDirectory, isDirectory: true)
            }

            do {
                try process.run()

                let group = DispatchGroup()
                let lock = NSLock()
                var stdoutData = Data()
                var stderrData = Data()

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    lock.lock()
                    stdoutData = data
                    lock.unlock()
                    group.leave()
                }

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    lock.lock()
                    stderrData = data
                    lock.unlock()
                    group.leave()
                }

                process.waitUntilExit()
                group.wait()

                let result = ShellResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus,
                    duration: Date().timeIntervalSince(startedAt)
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                let result = ShellResult(
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1,
                    duration: Date().timeIntervalSince(startedAt)
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
}
