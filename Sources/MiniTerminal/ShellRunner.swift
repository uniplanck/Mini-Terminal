import Foundation

struct ShellResult {
    let exitCode: Int32
    let duration: TimeInterval
    let wasCancelled: Bool
}

/// Handle to a running command. Safe to call from any thread.
final class ShellExecution {
    private let lock = NSLock()
    private var processGroup: pid_t = 0
    private var hasExited = false
    private var cancelled = false

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Asks the command to stop the way ⌃C would, then insists: SIGINT now,
    /// SIGTERM after 2 s, SIGKILL after 4 s. A second call kills immediately.
    func cancel() {
        lock.lock()
        let repeated = cancelled
        cancelled = true
        lock.unlock()

        if repeated {
            send(SIGKILL)
            return
        }
        send(SIGINT)
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.asyncAfter(deadline: .now() + 2) { self.send(SIGTERM) }
        queue.asyncAfter(deadline: .now() + 4) { self.send(SIGKILL) }
    }

    /// Stops the command without the grace period, for when the app itself is quitting.
    func terminate() {
        lock.lock()
        cancelled = true
        lock.unlock()
        send(SIGTERM)
    }

    fileprivate func started(processGroup: pid_t) {
        lock.lock()
        self.processGroup = processGroup
        lock.unlock()
    }

    /// Reaps the shell. The group id stays reserved until the reap, so signals
    /// sent under the lock can never reach an unrelated process.
    fileprivate func reap() -> Int32 {
        var info = siginfo_t()
        while waitid(P_PID, id_t(processGroup), &info, WEXITED | WNOWAIT) == -1 && errno == EINTR {}

        lock.lock()
        defer { lock.unlock() }
        // A stop request means the whole job: take down anything the shell left behind.
        if cancelled { kill(-processGroup, SIGKILL) }
        hasExited = true
        var status: Int32 = 0
        while waitpid(processGroup, &status, 0) == -1 && errno == EINTR {}
        let terminatingSignal = status & 0x7F
        return terminatingSignal == 0 ? (status >> 8) & 0xFF : 128 + terminatingSignal
    }

    private func send(_ value: Int32) {
        lock.lock()
        defer { lock.unlock() }
        guard processGroup > 0, !hasExited else { return }
        kill(-processGroup, value)
    }
}

final class ShellRunner {
    /// Runs `command` in a login shell. Output from stdout and stderr arrives on the
    /// main queue through `onOutput`, in the order it was written, while the command
    /// is still running. `completion` follows the last piece of output.
    @discardableResult
    func run(
        command: String,
        shellPath: String,
        workingDirectory: String,
        onOutput: @escaping (String) -> Void = { _ in },
        completion: @escaping (ShellResult) -> Void
    ) -> ShellExecution {
        let execution = ShellExecution()
        let startedAt = Date()

        func fail(_ code: Int32) -> ShellExecution {
            let message = "\(shellPath): \(String(cString: strerror(code)))"
            DispatchQueue.main.async {
                onOutput(message)
                completion(ShellResult(exitCode: -1, duration: Date().timeIntervalSince(startedAt), wasCancelled: false))
            }
            return execution
        }

        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { return fail(errno) }
        let (readEnd, writeEnd) = (descriptors[0], descriptors[1])
        _ = fcntl(readEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(readEnd, F_SETFL, O_NONBLOCK)

        var pid: pid_t = 0
        let spawnError = Self.spawn(
            shellPath: shellPath,
            command: command,
            workingDirectory: workingDirectory,
            output: writeEnd,
            pid: &pid
        )
        close(writeEnd)
        guard spawnError == 0 else {
            close(readEnd)
            return fail(spawnError)
        }

        execution.started(processGroup: pid)
        let pump = OutputPump(descriptor: readEnd, deliver: onOutput)
        pump.start()

        DispatchQueue.global(qos: .userInitiated).async {
            let exitCode = execution.reap()
            let duration = Date().timeIntervalSince(startedAt)
            pump.finish {
                completion(ShellResult(exitCode: exitCode, duration: duration, wasCancelled: execution.wasCancelled))
            }
        }
        return execution
    }

    /// Starts the shell as the leader of its own process group, so a stop request
    /// reaches every process in a pipeline rather than the shell alone.
    private static func spawn(
        shellPath: String,
        command: String,
        workingDirectory: String,
        output: Int32,
        pid: inout pid_t
    ) -> Int32 {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, output, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, output, STDERR_FILENO)

        let expandedWorkingDirectory = NSString(string: workingDirectory).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedWorkingDirectory) {
            posix_spawn_file_actions_addchdir_np(&actions, expandedWorkingDirectory)
        }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        var defaultSignals = sigset_t()
        sigfillset(&defaultSignals)
        posix_spawnattr_setsigdefault(&attributes, &defaultSignals)
        var blockedSignals = sigset_t()
        sigemptyset(&blockedSignals)
        posix_spawnattr_setsigmask(&attributes, &blockedSignals)
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setflags(
            &attributes,
            Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_CLOEXEC_DEFAULT)
        )

        let arguments: [UnsafeMutablePointer<CChar>?] = [shellPath, "-lc", command].map { strdup($0) } + [nil]
        let environment: [UnsafeMutablePointer<CChar>?] =
            ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            arguments.forEach { free($0) }
            environment.forEach { free($0) }
        }
        return posix_spawn(&pid, shellPath, &actions, &attributes, arguments, environment)
    }
}

/// Reads the command's output pipe and hands text to the main queue at most
/// about 30 times a second. When more than `pendingLimit` is waiting for the UI,
/// reading pauses and the pipe fills, which slows the command down the way a
/// terminal would instead of flooding the app.
private final class OutputPump {
    private static let deliveryInterval: TimeInterval = 0.03
    private static let pendingLimit = 1_000_000

    private let descriptor: Int32
    private let deliver: (String) -> Void
    private let queue = DispatchQueue(label: "com.nao.mini-terminal.output", qos: .userInitiated)
    private let source: DispatchSourceRead
    private var readBuffer = [UInt8](repeating: 0, count: 65_536)
    private var decoder = UTF8StreamDecoder()
    private var reachedEnd = false
    private var isPaused = false

    private let lock = NSLock()
    private var pending = ""
    private var deliveryScheduled = false
    private var lastDelivery = Date.distantPast

    init(descriptor: Int32, deliver: @escaping (String) -> Void) {
        self.descriptor = descriptor
        self.deliver = deliver
        source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
    }

    func start() {
        let descriptor = descriptor
        source.setEventHandler { [weak self] in self?.drain(maximumReads: 64) }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    /// Collects what the shell wrote before it exited, then calls `completion` on the
    /// main queue after the last text. Output a background child writes later is not
    /// waited for: the command is over once the shell is.
    func finish(_ completion: @escaping () -> Void) {
        queue.async {
            self.drain(maximumReads: 256, pausesWhenFull: false)
            self.post(self.decoder.finish())
            self.stopReading()
            DispatchQueue.main.async {
                self.deliverPending()
                completion()
            }
        }
    }

    private func drain(maximumReads: Int, pausesWhenFull: Bool = true) {
        guard !reachedEnd else { return }
        for _ in 0..<maximumReads {
            let count = read(descriptor, &readBuffer, readBuffer.count)
            if count > 0 {
                let waiting = post(decoder.decode(readBuffer[0..<count]))
                if pausesWhenFull, waiting > Self.pendingLimit {
                    isPaused = true
                    source.suspend()
                    return
                }
            } else if count == 0 {
                stopReading()
                return
            } else if errno != EINTR {
                return
            }
        }
    }

    private func stopReading() {
        guard !reachedEnd else { return }
        reachedEnd = true
        resumeReading()
        source.cancel()
    }

    private func resumeReading() {
        guard isPaused else { return }
        isPaused = false
        source.resume()
    }

    /// Queues text for the main queue and returns how many bytes are now waiting.
    @discardableResult
    private func post(_ text: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard !text.isEmpty else { return pending.utf8.count }
        pending += text
        if !deliveryScheduled {
            deliveryScheduled = true
            let wait = max(0, Self.deliveryInterval - Date().timeIntervalSince(lastDelivery))
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.deliverPending() }
        }
        return pending.utf8.count
    }

    private func deliverPending() {
        lock.lock()
        let text = pending
        pending = ""
        deliveryScheduled = false
        lock.unlock()
        if !text.isEmpty { deliver(text) }
        lock.lock()
        lastDelivery = Date()
        lock.unlock()
        queue.async { self.resumeReading() }
    }
}

/// Decodes UTF-8 that arrives split at arbitrary byte boundaries. A character cut
/// in two is held until its remaining bytes arrive; invalid bytes become U+FFFD
/// instead of discarding the surrounding text.
struct UTF8StreamDecoder {
    private var carry: [UInt8] = []

    mutating func decode<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        carry.append(contentsOf: bytes)
        let complete = Self.completePrefixLength(carry)
        let text = String(decoding: carry[0..<complete], as: UTF8.self)
        carry.removeFirst(complete)
        return text
    }

    mutating func finish() -> String {
        defer { carry.removeAll() }
        return String(decoding: carry, as: UTF8.self)
    }

    private static func completePrefixLength(_ bytes: [UInt8]) -> Int {
        var index = bytes.count - 1
        while index >= 0, bytes.count - index <= 4 {
            let byte = bytes[index]
            if byte & 0xC0 != 0x80 {
                let needed = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : byte >= 0xC0 ? 2 : 1
                return bytes.count - index < needed ? index : bytes.count
            }
            index -= 1
        }
        return bytes.count
    }
}
