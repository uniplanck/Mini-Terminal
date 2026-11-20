import Foundation

/// Display text for command output that arrives in pieces.
///
/// Without a terminal, two conventions still show up in real output: a carriage
/// return that redraws a progress line in place, and ANSI escape sequences.
/// The first is honoured, the second is dropped. The text is kept to a bounded tail.
struct OutputBuffer {
    static let defaultLimit = 2_000_000

    /// Finished lines. Within one `generation` this only grows at the end
    /// (or loses trailing newlines in `finish`), so a view can append instead of redrawing.
    private(set) var committed = ""
    private(set) var committedUTF16Count = 0
    /// The line still being written.
    private(set) var currentLine = ""
    /// Replaced whenever the start of `committed` changes.
    private(set) var generation = UUID()
    /// True once older output has been dropped to stay within the limit.
    private(set) var isTruncated = false

    private let limit: Int
    private var pendingCarriageReturn = false
    private var escape = EscapeState.none

    private enum EscapeState {
        case none, started, controlSequence, operatingSystemCommand
    }

    init(limit: Int = OutputBuffer.defaultLimit) {
        self.limit = max(limit, 16)
    }

    init(text: String) {
        self.init()
        committed = text
        committedUTF16Count = text.utf16.count
    }

    var text: String { currentLine.isEmpty ? committed : committed + currentLine }
    var isEmpty: Bool { committed.isEmpty && currentLine.isEmpty }

    mutating func append(_ chunk: String) {
        let bytes = chunk.utf8
        var runStart: String.UTF8View.Index?

        func flushRun(to end: String.UTF8View.Index, into buffer: inout OutputBuffer) {
            guard let start = runStart else { return }
            runStart = nil
            buffer.write(Substring(bytes[start..<end]))
        }

        for index in bytes.indices {
            let byte = bytes[index]
            switch escape {
            case .none:
                switch byte {
                case 0x0A:
                    flushRun(to: index, into: &self)
                    commitLine()
                case 0x0D:
                    flushRun(to: index, into: &self)
                    pendingCarriageReturn = true
                case 0x1B:
                    flushRun(to: index, into: &self)
                    escape = .started
                default:
                    if runStart == nil { runStart = index }
                }
            case .started:
                switch byte {
                case 0x5B: escape = .controlSequence
                case 0x5D: escape = .operatingSystemCommand
                default: escape = .none
                }
            case .controlSequence:
                if (0x40...0x7E).contains(byte) { escape = .none }
            case .operatingSystemCommand:
                if byte == 0x07 { escape = .none } else if byte == 0x1B { escape = .started }
            }
        }
        flushRun(to: bytes.endIndex, into: &self)
        trimIfNeeded()
    }

    /// Call once when the command has ended. Trailing newlines are dropped so the
    /// result pastes cleanly; a progress line left without a newline is kept.
    mutating func finish() {
        pendingCarriageReturn = false
        escape = .none
        guard currentLine.isEmpty else { return }
        var trailing = 0
        for byte in committed.utf8.reversed() {
            guard byte == 0x0A else { break }
            trailing += 1
        }
        guard trailing > 0 else { return }
        committed.removeLast(trailing)
        committedUTF16Count -= trailing
    }

    private mutating func write(_ run: Substring) {
        if pendingCarriageReturn {
            currentLine.removeAll(keepingCapacity: true)
            pendingCarriageReturn = false
        }
        currentLine.append(contentsOf: run)
    }

    private mutating func commitLine() {
        committed.append(currentLine)
        committed.append("\n")
        committedUTF16Count += currentLine.utf16.count + 1
        currentLine.removeAll(keepingCapacity: true)
        pendingCarriageReturn = false
    }

    private mutating func trimIfNeeded() {
        // Cut back well below the limit so a steady stream does not trim on every append.
        let keep = limit * 3 / 4
        if committed.utf8.count > limit {
            let utf8 = committed.utf8
            let cut = utf8.index(utf8.startIndex, offsetBy: utf8.count - keep)
            if let newline = utf8[cut...].firstIndex(of: 0x0A) {
                committed = String(committed[utf8.index(after: newline)...])
            } else {
                committed = ""
            }
            committedUTF16Count = committed.utf16.count
            generation = UUID()
            isTruncated = true
        }
        if currentLine.utf8.count > limit {
            currentLine = String(String.UnicodeScalarView(currentLine.unicodeScalars.suffix(keep / 4)))
            isTruncated = true
        }
    }
}
