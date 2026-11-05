import XCTest
import CoreGraphics
@testable import PeekshCore

final class PanelLayoutTests: XCTestCase {
    func testSizeLimitsMatchTheMaximumFrameAndNativeMinimums() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let limits = PanelLayout.sizeLimits(mode: .compact, visibleFrame: screen)
        XCTAssertEqual(limits.minimum, CGSize(width: 520, height: 300))
        XCTAssertEqual(limits.maximum, CGSize(width: 1488, height: 958))
        let frame = PanelLayout.frame(mode: .compact, visibleFrame: screen, anchor: nil,
                                     compactSize: CGSize(width: 9000, height: 9000))
        XCTAssertEqual(frame.size, limits.maximum)
    }

    func testSizeLimitsRemainValidOnNarrowAndShortDisplays() {
        for size in [CGSize(width: 360, height: 240), CGSize(width: 800, height: 200), CGSize(width: 20, height: 20)] {
            let limits = PanelLayout.sizeLimits(mode: .compact, visibleFrame: CGRect(origin: .zero, size: size))
            XCTAssertLessThanOrEqual(limits.minimum.width, limits.maximum.width)
            XCTAssertLessThanOrEqual(limits.minimum.height, limits.maximum.height)
        }
    }

    func testRememberedFrameMovesWithDisplayAndClampsAfterResolutionChange() {
        let savedVisible = CGRect(x: 1920, y: -400, width: 1920, height: 1080)
        let visible = CGRect(x: -1280, y: 0, width: 1280, height: 800)
        let remembered = RememberedPanelFrame(frame: CGRect(x: 2900, y: -300, width: 1600, height: 900),
                                              visibleFrame: savedVisible)
        let frame = remembered.restored(in: visible)
        XCTAssertTrue(visible.contains(frame))
        XCTAssertEqual(frame.width, 1256)
        XCTAssertEqual(frame.height, 776)
    }

    func testWindowStaysOnScreenAtEitherMenuBarEdge() {
        let screen = CGRect(x: -1920, y: 140, width: 1920, height: 1055)
        for x in [-1920.0, -10.0] {
            let frame = PanelLayout.frame(mode: .compact, visibleFrame: screen,
                                          anchor: CGRect(x: x, y: screen.maxY, width: 24, height: 24))
            XCTAssertTrue(screen.contains(frame))
            XCTAssertEqual(frame.maxY, screen.maxY - 12)
        }
    }

    func testWindowUsesChosenDimensions() {
        let screen = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let frame = PanelLayout.frame(mode: .compact, visibleFrame: screen, anchor: nil,
                                      compactSize: CGSize(width: 600, height: 340))
        XCTAssertEqual(frame.size, CGSize(width: 600, height: 340))
    }

    func testSmallDisplaysNeverProduceAnOffscreenPanel() {
        let screen = CGRect(x: 0, y: 0, width: 360, height: 240)
        XCTAssertTrue(screen.contains(PanelLayout.frame(mode: .compact, visibleFrame: screen, anchor: nil)))
    }
}
