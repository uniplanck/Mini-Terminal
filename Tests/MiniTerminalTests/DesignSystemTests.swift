import XCTest
@testable import MiniTerminal

final class DesignSystemTests: XCTestCase {
    func testSharedLauncherLayoutInvariants() {
        XCTAssertEqual(UIParameters.toolbarTarget, 32)
        XCTAssertEqual(UIParameters.paneHeaderHeight, 40)
        XCTAssertEqual(UIParameters.statusHeight, 40)
        XCTAssertEqual(UIParameters.historyRowHeight, 40)
        XCTAssertGreaterThanOrEqual(UIParameters.compactWidth, 640)
    }

    func testCommandFieldGrowsWithItsTextUpToSixLinesInCompactLayoutOnly() {
        let line = UIParameters.codeLineHeight
        XCTAssertEqual(UIParameters.commandFieldHeight(contentHeight: 0, split: false), line)
        XCTAssertEqual(UIParameters.commandFieldHeight(contentHeight: line * 3, split: false), line * 3)
        XCTAssertEqual(UIParameters.commandFieldHeight(contentHeight: line * 40, split: false), line * 6)
        XCTAssertEqual(UIParameters.commandFieldHeight(contentHeight: line * 40, split: true), line)
        XCTAssertEqual(UIParameters.commandBarHeight(fieldHeight: line), UIParameters.compactCommandHeight)
        XCTAssertEqual(UIParameters.commandBarHeight(fieldHeight: line * 3), UIParameters.compactCommandHeight + line * 2)
    }

    func testCompactLauncherGrowsForOutputAndForALongCommand() {
        let line = UIParameters.codeLineHeight
        XCTAssertEqual(UIParameters.launcherSize(split: false, history: false, showsOutput: true),
                       CGSize(width: 720, height: 96 + UIParameters.compactOutputHeight))
        XCTAssertEqual(UIParameters.launcherSize(split: false, history: false, commandFieldHeight: line * 4),
                       CGSize(width: 720, height: 96 + line * 3))
        XCTAssertEqual(UIParameters.launcherSize(split: true, history: false, showsOutput: true),
                       CGSize(width: 900, height: 480), "split layout already has its own output pane")
        XCTAssertEqual(UIParameters.launcherSize(split: false, history: false, showsOutput: true,
                                                 available: CGSize(width: 800, height: 300)).height, 268)
    }

    func testDurationUsesTheUnitThatFitsTheLengthOfTheRun() {
        XCTAssertEqual(DurationFormat.string(0.0124), "12 ms")
        XCTAssertEqual(DurationFormat.string(0.9996), "1.0 s")
        XCTAssertEqual(DurationFormat.string(12.34), "12.3 s")
        XCTAssertEqual(DurationFormat.string(59.96), "1m 00s")
        XCTAssertEqual(DurationFormat.string(1_205.4), "20m 05s")
        XCTAssertEqual(DurationFormat.string(3_723), "1h 02m 03s")
    }
}
