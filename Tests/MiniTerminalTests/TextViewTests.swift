import AppKit
import XCTest
@testable import MiniTerminal

final class CommandInputTests: XCTestCase {
    private var window: NSWindow?

    override func tearDown() {
        window?.close()
        window = nil
    }

    private func makeController(fieldMode: Bool = true, size: NSSize = NSSize(width: 400, height: 120)) -> CommandInputController {
        _ = NSApplication.shared
        let controller = CommandInputController(inset: .zero, identifier: "launcher.command")
        controller.returnRuns = fieldMode
        controller.scrollView.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: controller.scrollView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = controller.scrollView
        controller.scrollView.layoutSubtreeIfNeeded()
        self.window = window
        return controller
    }

    func testInputStaysSelectableAndScrollableWhileACommandRuns() {
        let controller = makeController()
        controller.apply(text: (1...50).map { "line \($0)" }.joined(separator: "\n"), isEditable: false)

        XCTAssertFalse(controller.textView.isEditable)
        XCTAssertTrue(controller.textView.isSelectable)
        controller.textView.layoutManager?.ensureLayout(for: controller.textView.textContainer!)
        controller.textView.sizeToFit()
        XCTAssertGreaterThan(controller.textView.frame.height, controller.scrollView.contentSize.height,
                             "the whole script is laid out and reachable by scrolling")

        controller.apply(text: controller.textView.string, isEditable: true)
        XCTAssertTrue(controller.textView.isEditable)
    }

    func testShellTextIsNeverRewrittenByAutomaticSubstitution() {
        let textView = makeController().textView
        XCTAssertFalse(textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(textView.isAutomaticSpellingCorrectionEnabled)
        XCTAssertFalse(textView.isContinuousSpellCheckingEnabled)
        XCTAssertFalse(textView.isRichText)
        XCTAssertEqual(textView.accessibilityIdentifier(), "launcher.command")
    }

    func testReturnRunsAndShiftReturnInsertsALineInFieldMode() {
        let controller = makeController()
        var submitted = 0
        var edited = ""
        controller.onSubmit = { submitted += 1 }
        controller.onTextChange = { edited = $0 }
        controller.apply(text: "echo a", isEditable: true)

        XCTAssertTrue(controller.handle(#selector(NSResponder.insertNewline(_:)), modifiers: []))
        XCTAssertEqual(submitted, 1)
        XCTAssertEqual(controller.textView.string, "echo a")

        XCTAssertTrue(controller.handle(#selector(NSResponder.insertNewline(_:)), modifiers: .shift))
        XCTAssertEqual(submitted, 1)
        XCTAssertEqual(controller.textView.string, "echo a\n")
        XCTAssertEqual(edited, "echo a\n")
    }

    func testReturnIsAnOrdinaryNewlineInTheEditor() {
        let controller = makeController(fieldMode: false)
        var submitted = 0
        controller.onSubmit = { submitted += 1 }
        XCTAssertFalse(controller.handle(#selector(NSResponder.insertNewline(_:)), modifiers: []))
        XCTAssertEqual(submitted, 0)
    }

    func testArrowsRecallHistoryOnlyFromTheFirstAndLastLine() {
        let controller = makeController()
        var recalled: [String] = []
        controller.onHistoryPrevious = { recalled.append("previous") }
        controller.onHistoryNext = { recalled.append("next") }
        controller.apply(text: "first\nsecond\nthird", isEditable: true)
        let up = #selector(NSResponder.moveUp(_:))
        let down = #selector(NSResponder.moveDown(_:))

        // apply() leaves the caret at the end, on the last line.
        XCTAssertFalse(controller.handle(up, modifiers: []))
        XCTAssertTrue(controller.handle(down, modifiers: []))

        controller.textView.setSelectedRange(NSRange(location: 8, length: 0))
        XCTAssertFalse(controller.handle(up, modifiers: []))
        XCTAssertFalse(controller.handle(down, modifiers: []))

        controller.textView.setSelectedRange(NSRange(location: 2, length: 0))
        XCTAssertTrue(controller.handle(up, modifiers: []))
        XCTAssertFalse(controller.handle(down, modifiers: []))
        XCTAssertEqual(recalled, ["next", "previous"])

        controller.apply(text: "", isEditable: true)
        XCTAssertTrue(controller.handle(up, modifiers: []))
        XCTAssertTrue(controller.handle(down, modifiers: []))
    }

    func testEditorDoesNotRecallHistory() {
        let controller = makeController(fieldMode: false)
        controller.apply(text: "one line", isEditable: true)
        XCTAssertFalse(controller.handle(#selector(NSResponder.moveUp(_:)), modifiers: []))
    }

    func testContentHeightFollowsTheNumberOfDisplayedLines() {
        let controller = makeController()
        let inset: CGFloat = 0
        controller.apply(text: "", isEditable: true)
        XCTAssertEqual(controller.contentHeight, UIParameters.codeLineHeight + inset)
        controller.apply(text: "one", isEditable: true)
        XCTAssertEqual(controller.contentHeight, UIParameters.codeLineHeight + inset)
        controller.apply(text: "one\ntwo\nthree", isEditable: true)
        XCTAssertEqual(controller.contentHeight, UIParameters.codeLineHeight * 3 + inset)

        // A long one-liner wraps, and the wrapped lines count too.
        controller.apply(text: String(repeating: "ffmpeg -i input.mov ", count: 12), isEditable: true)
        XCTAssertGreaterThan(controller.contentHeight, UIParameters.codeLineHeight * 3 + inset)
    }

    func testFocusRequestGoesOnlyToTheDesignatedInput() {
        let controller = makeController()
        controller.takesFocusOnRequest = false
        NotificationCenter.default.post(name: .miniTerminalFocusCommand, object: nil)
        XCTAssertFalse(window?.firstResponder === controller.textView)

        controller.takesFocusOnRequest = true
        NotificationCenter.default.post(name: .miniTerminalFocusCommand, object: nil)
        XCTAssertTrue(window?.firstResponder === controller.textView)
    }
}

final class OutputTextTests: XCTestCase {
    private var window: NSWindow?

    override func tearDown() {
        window?.close()
        window = nil
    }

    private func makeController() -> OutputTextController {
        _ = NSApplication.shared
        let controller = OutputTextController(identifier: "launcher.output")
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
        let window = NSWindow(contentRect: controller.scrollView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = controller.scrollView
        controller.scrollView.layoutSubtreeIfNeeded()
        self.window = window
        return controller
    }

    private func lines(_ range: ClosedRange<Int>) -> String {
        range.map { "output line \($0)\n" }.joined()
    }

    /// The published state is updated on a later main-queue turn.
    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    private func scrollToTop(_ controller: OutputTextController) {
        controller.scrollView.contentView.scroll(to: .zero)
        controller.scrollView.reflectScrolledClipView(controller.scrollView.contentView)
        controller.readerDidScroll()
    }

    func testOutputIsReadOnlySelectableAndIdentified() {
        let textView = makeController().textView
        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertEqual(textView.accessibilityIdentifier(), "launcher.output")
    }

    func testFollowsTheEndWhileTheReaderStaysThere() {
        let controller = makeController()
        var buffer = OutputBuffer()
        buffer.append(lines(1...200))
        controller.render(buffer)
        XCTAssertTrue(controller.isFollowing)
        XCTAssertTrue(controller.isAtEnd)
        XCTAssertGreaterThan(controller.scrollView.contentView.bounds.origin.y, 1_000)

        buffer.append(lines(201...400))
        controller.render(buffer)
        XCTAssertTrue(controller.isAtEnd)
    }

    func testStopsFollowingOnceTheReaderScrollsUpAndResumesOnRequest() {
        let controller = makeController()
        let state = OutputScrollState()
        controller.state = state
        var buffer = OutputBuffer()
        buffer.append(lines(1...200))
        controller.render(buffer)

        scrollToTop(controller)
        XCTAssertFalse(controller.isFollowing)

        buffer.append(lines(201...400))
        controller.render(buffer)
        XCTAssertEqual(controller.scrollView.contentView.bounds.origin.y, 0, "new output must not move a reader who scrolled away")
        XCTAssertFalse(controller.isAtEnd)
        XCTAssertTrue(waitUntil { !state.isFollowing })

        state.jumpToLatest()
        XCTAssertTrue(controller.isFollowing)
        XCTAssertTrue(controller.isAtEnd)
        XCTAssertTrue(waitUntil { state.isFollowing })
    }

    func testScrollingBackToTheEndResumesFollowing() {
        let controller = makeController()
        var buffer = OutputBuffer()
        buffer.append(lines(1...200))
        controller.render(buffer)
        scrollToTop(controller)
        XCTAssertFalse(controller.isFollowing)

        let clip = controller.scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: controller.textView.frame.height - clip.bounds.height))
        controller.readerDidScroll()
        XCTAssertTrue(controller.isFollowing)
    }

    func testANewRunStartsFollowingAgain() {
        let controller = makeController()
        var buffer = OutputBuffer()
        buffer.append(lines(1...200))
        controller.render(buffer)
        scrollToTop(controller)

        controller.render(OutputBuffer())
        XCTAssertTrue(controller.isFollowing)
        XCTAssertEqual(controller.textView.string, "")
    }

    func testDisplayedTextMatchesTheBufferThroughEveryKindOfUpdate() {
        let controller = makeController()
        var buffer = OutputBuffer(limit: 2_000)
        func check(_ message: String) {
            controller.render(buffer)
            XCTAssertEqual(controller.textView.string, buffer.text, message)
        }

        buffer.append("start\n")
        check("first lines")
        buffer.append("frame=1\r")
        check("progress line")
        buffer.append("frame=2 進捗🙂\r")
        check("progress line redrawn")
        buffer.append("frame=3\nnext\n")
        check("progress line committed")
        for index in 0..<300 { buffer.append("filler \(index)\n") }
        XCTAssertTrue(buffer.isTruncated)
        check("older output dropped")
        buffer.append("tail\n\n")
        check("append after truncation")
        buffer.finish()
        check("trailing newlines removed")
        XCTAssertTrue(controller.textView.string.hasSuffix("tail"))

        controller.render(OutputBuffer(text: "restored\nfrom history"))
        XCTAssertEqual(controller.textView.string, "restored\nfrom history")
    }

    func testWrappingCanBeTurnedOffForWideOutput() {
        let controller = makeController()
        var buffer = OutputBuffer()
        buffer.append(String(repeating: "wide ", count: 200) + "\n")
        controller.render(buffer)
        let clipWidth = controller.scrollView.contentSize.width

        XCTAssertTrue(controller.wrapsLines)
        XCTAssertFalse(controller.scrollView.hasHorizontalScroller)
        XCTAssertLessThanOrEqual(controller.textView.frame.width, clipWidth)
        let wrappedHeight = controller.textView.frame.height

        controller.setWrapsLines(false)
        controller.textView.layoutManager?.ensureLayout(for: controller.textView.textContainer!)
        controller.textView.sizeToFit()
        XCTAssertTrue(controller.scrollView.hasHorizontalScroller)
        XCTAssertGreaterThan(controller.textView.frame.width, clipWidth)
        XCTAssertLessThan(controller.textView.frame.height, wrappedHeight)

        controller.setWrapsLines(true)
        controller.textView.layoutManager?.ensureLayout(for: controller.textView.textContainer!)
        controller.textView.sizeToFit()
        XCTAssertFalse(controller.scrollView.hasHorizontalScroller)
        XCTAssertLessThanOrEqual(controller.textView.frame.width, clipWidth)
    }

    func testFollowingAWideLineDoesNotJumpSideways() {
        let controller = makeController()
        controller.setWrapsLines(false)
        var buffer = OutputBuffer()
        buffer.append(lines(1...100) + String(repeating: "wide ", count: 200))
        controller.render(buffer)
        XCTAssertEqual(controller.scrollView.contentView.bounds.origin.x, 0)
        XCTAssertTrue(controller.isAtEnd)
    }
}

final class OutputFloodTests: XCTestCase {
    /// A flood delivers about 1 MB per tick. The work per tick has to leave the
    /// main thread free often enough for the stop button to respond.
    func testRenderingAFloodStaysCheapPerTick() {
        _ = NSApplication.shared
        let controller = OutputTextController(identifier: "launcher.output")
        controller.scrollView.frame = NSRect(x: 0, y: 0, width: 440, height: 400)
        let window = NSWindow(contentRect: controller.scrollView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = controller.scrollView
        defer { window.close() }

        let chunk = String(repeating: "flood line for mini-terminal\n", count: 1_000_000 / 29)
        var buffer = OutputBuffer()
        var slowest: TimeInterval = 0
        var total: TimeInterval = 0
        let ticks = 30
        for _ in 0..<ticks {
            let started = Date()
            buffer.append(chunk)
            controller.render(buffer)
            let elapsed = Date().timeIntervalSince(started)
            slowest = max(slowest, elapsed)
            total += elapsed
        }
        print(String(format: "FLOOD_TICK_MS mean=%.1f slowest=%.1f", total / Double(ticks) * 1_000, slowest * 1_000))

        XCTAssertTrue(buffer.isTruncated)
        XCTAssertEqual(controller.textView.string, buffer.text)
        XCTAssertTrue(controller.isAtEnd)
        XCTAssertLessThan(total / Double(ticks), 0.1)
    }
}
