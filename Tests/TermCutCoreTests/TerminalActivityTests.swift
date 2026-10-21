import XCTest
@testable import TermCutCore

final class TerminalActivityTests: XCTestCase {
    func testShellReportsUseExitStatus() {
        XCTAssertEqual(TerminalActivity(shellReport: "start"), .running)
        XCTAssertEqual(TerminalActivity(shellReport: "done;0"), .ready)
        XCTAssertEqual(TerminalActivity(shellReport: "done;127"), .failed(127))
        XCTAssertEqual(TerminalActivity(shellReport: "done;130"), .failed(130))
        for report in ["error", "done;", "done;-1", "done;256", "done;1;extra"] {
            XCTAssertNil(TerminalActivity(shellReport: report))
        }
    }

    func testHiddenFailuresTakePriorityUntilTheirSessionChangesOrCloses() {
        XCTAssertEqual(TerminalActivity.combined([.ready, .running, .failed(2)]), .failed(2))
        XCTAssertEqual(TerminalActivity.combined([.ready, .running]), .running)
        XCTAssertEqual(TerminalActivity.combined([.ended, .ready]), .ready)
        XCTAssertEqual(TerminalActivity.combined([.ended, .unavailable]), .unavailable)
        XCTAssertEqual(TerminalActivity.combined([.ready, .unavailable]), .unavailable)
        XCTAssertEqual(TerminalActivity.combined([]), .ended)
    }
}
