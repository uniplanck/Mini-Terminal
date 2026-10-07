import XCTest
@testable import MiniTerminal

final class DesignSystemTests: XCTestCase {
    func testSharedLauncherLayoutInvariants() {
        XCTAssertEqual(UIParameters.toolbarTarget, 32)
        XCTAssertEqual(UIParameters.commandFieldHeight, 40)
        XCTAssertEqual(UIParameters.paneHeaderHeight, 40)
        XCTAssertEqual(UIParameters.statusHeight, 40)
        XCTAssertEqual(UIParameters.historyRowHeight, 40)
        XCTAssertGreaterThanOrEqual(UIParameters.compactWidth, 640)
    }
}
