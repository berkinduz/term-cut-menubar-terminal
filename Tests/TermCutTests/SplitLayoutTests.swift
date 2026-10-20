import AppKit
import XCTest
import TermCutCore
@testable import TermCut

@MainActor
final class SplitLayoutTests: XCTestCase {
    private func split(axis: SplitAxis, size: NSSize, fraction: Double) -> ProportionalSplitView {
        let view = ProportionalSplitView(axis: axis, fraction: fraction)
        view.addArrangedSubview(NSView())
        view.addArrangedSubview(NSView())
        view.setFrameSize(size)
        view.adjustSubviews()
        return view
    }

    func testHorizontalSplitKeepsItsProportionWhenTheWindowResizes() async {
        let view = split(axis: .horizontal, size: NSSize(width: 1000, height: 600), fraction: 0.7)
        XCTAssertEqual(view.arrangedSubviews[0].frame.width, (1000 - view.dividerThickness) * 0.7, accuracy: 1)
        view.setFrameSize(NSSize(width: 1400, height: 800))
        view.adjustSubviews()
        XCTAssertEqual(view.arrangedSubviews[0].frame.width, (1400 - view.dividerThickness) * 0.7, accuracy: 1)
        XCTAssertEqual(view.arrangedSubviews[1].frame.maxX, 1400, accuracy: 1)
    }

    func testVerticalSplitRestoresTheSavedProportionAfterRecreation() async {
        let view = split(axis: .vertical, size: NSSize(width: 900, height: 600), fraction: 0.5)
        XCTAssertTrue(view.isFlipped, "The existing pane stays above a newly created split")
        var saved: Double = 0.5
        view.onFractionChanged = { saved = $0 }
        view.setPosition(200, ofDividerAt: 0)
        view.splitViewDidResizeSubviews(Notification(name: NSSplitView.didResizeSubviewsNotification, object: view))
        let restored = split(axis: .vertical, size: NSSize(width: 900, height: 800), fraction: saved)
        XCTAssertEqual(saved, 200 / (600 - view.dividerThickness), accuracy: 0.01)
        XCTAssertEqual(restored.arrangedSubviews[0].frame.height, (800 - restored.dividerThickness) * saved, accuracy: 1)
    }
}
