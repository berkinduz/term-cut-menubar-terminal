import XCTest
import CoreGraphics
@testable import TermCutCore

final class PanelLayoutTests: XCTestCase {
    func testCompactStaysOnScreenAtEitherMenuBarEdge() {
        let screen = CGRect(x: -1920, y: 140, width: 1920, height: 1055)
        for x in [-1920.0, -10.0] {
            let frame = PanelLayout.frame(mode: .compact, visibleFrame: screen,
                                          anchor: CGRect(x: x, y: screen.maxY, width: 24, height: 24))
            XCTAssertTrue(screen.contains(frame))
            XCTAssertEqual(frame.maxY, screen.maxY - 12)
        }
    }

    func testDropDownUsesTheChosenDisplayAndHeight() {
        let screen = CGRect(x: 1512, y: -400, width: 1920, height: 1080)
        let frame = PanelLayout.frame(mode: .dropDown, visibleFrame: screen, anchor: nil, dropDownHeight: 0.6)
        XCTAssertEqual(frame.width, 1896)
        XCTAssertEqual(frame.height, 648)
        XCTAssertEqual(frame.minX, 1524)
        XCTAssertEqual(frame.maxY, screen.maxY - 12)
    }

    func testSmallDisplaysNeverProduceAnOffscreenPanel() {
        let screen = CGRect(x: 0, y: 0, width: 360, height: 240)
        for mode in PanelMode.allCases {
            let frame = PanelLayout.frame(mode: mode, visibleFrame: screen, anchor: nil)
            XCTAssertTrue(screen.contains(frame))
        }
    }
}
