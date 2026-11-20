import XCTest
@testable import MiniTerminal

final class OutputBufferTests: XCTestCase {
    func testCarriageReturnRedrawsTheCurrentLine() {
        var buffer = OutputBuffer()
        buffer.append("start\nframe=1\rframe=2\rframe=")
        XCTAssertEqual(buffer.text, "start\nframe=")
        buffer.append("3")
        XCTAssertEqual(buffer.text, "start\nframe=3")
        XCTAssertEqual(buffer.committed, "start\n")
        XCTAssertEqual(buffer.currentLine, "frame=3")
    }

    func testProgressLineStaysVisibleUntilItIsOverwritten() {
        var buffer = OutputBuffer()
        buffer.append("frame=1\r")
        XCTAssertEqual(buffer.text, "frame=1")
        buffer.append("frame=2\r")
        XCTAssertEqual(buffer.text, "frame=2")
    }

    func testCarriageReturnLineFeedIsAnOrdinaryNewline() {
        var buffer = OutputBuffer()
        buffer.append("one\r")
        buffer.append("\ntwo\r\n")
        XCTAssertEqual(buffer.text, "one\ntwo\n")
    }

    func testEscapeSequencesAreDroppedEvenWhenSplitAcrossChunks() {
        var buffer = OutputBuffer()
        buffer.append("\u{1B}[1;31mred\u{1B}")
        buffer.append("[0m plain \u{1B}]0;title\u{07}end\u{1B}[")
        buffer.append("2K!")
        XCTAssertEqual(buffer.text, "red plain end!")
    }

    func testMultibyteTextSurvives() {
        var buffer = OutputBuffer()
        buffer.append("進捗 50%\r進捗 100%\n完了🙂")
        XCTAssertEqual(buffer.text, "進捗 100%\n完了🙂")
        XCTAssertEqual(buffer.committedUTF16Count, "進捗 100%\n".utf16.count)
    }

    func testFinishDropsTrailingNewlinesOnly() {
        var buffer = OutputBuffer()
        buffer.append("\nvalue\n\n")
        buffer.finish()
        XCTAssertEqual(buffer.text, "\nvalue")
        XCTAssertEqual(buffer.committedUTF16Count, 6)

        var progress = OutputBuffer()
        progress.append("done\nframe=9\r")
        progress.finish()
        XCTAssertEqual(progress.text, "done\nframe=9")
    }

    func testKeepsABoundedTailAndReportsTruncation() {
        var buffer = OutputBuffer(limit: 1_000)
        let firstGeneration = buffer.generation
        for index in 0..<500 { buffer.append("line \(index)\n") }

        XCTAssertTrue(buffer.isTruncated)
        XCTAssertNotEqual(buffer.generation, firstGeneration)
        XCTAssertLessThanOrEqual(buffer.text.utf8.count, 1_000)
        XCTAssertTrue(buffer.text.hasSuffix("line 499\n"))
        XCTAssertTrue(buffer.text.hasPrefix("line "), "the tail starts on a line boundary")
        XCTAssertEqual(buffer.committedUTF16Count, buffer.committed.utf16.count)
    }

    func testAppendingWithinTheLimitKeepsTheGeneration() {
        var buffer = OutputBuffer()
        let generation = buffer.generation
        buffer.append("a\nb\n")
        XCTAssertEqual(buffer.generation, generation)
        XCTAssertFalse(buffer.isTruncated)
    }

    func testAVeryLongLineWithoutNewlineIsBounded() {
        var buffer = OutputBuffer(limit: 1_000)
        buffer.append(String(repeating: "x", count: 5_000))
        XCTAssertTrue(buffer.isTruncated)
        XCTAssertLessThanOrEqual(buffer.text.utf8.count, 1_000)
    }

    func testRestoredTextIsShownAsIs() {
        let buffer = OutputBuffer(text: "saved\noutput")
        XCTAssertEqual(buffer.text, "saved\noutput")
        XCTAssertEqual(buffer.committedUTF16Count, 12)
        XCTAssertFalse(buffer.isEmpty)
        XCTAssertTrue(OutputBuffer().isEmpty)
    }
}
