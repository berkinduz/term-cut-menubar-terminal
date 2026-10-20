import XCTest
@testable import TermCutCore

final class PaneTreeTests: XCTestCase {
    func testNestedSplitPreservesOtherPanesAndOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        let tree = PaneTree.leaf(a).splitting(a, axis: .horizontal, newPane: b)
            .splitting(b, axis: .vertical, newPane: c)
        XCTAssertEqual(tree.leaves, [a, b, c])
        XCTAssertEqual(tree.removing(b), .split(.horizontal, .leaf(a), .leaf(c)))
        XCTAssertEqual(tree.removing(a), .split(.vertical, .leaf(b), .leaf(c)))
    }

    func testClosingLastPaneRemovesTheLayout() {
        let id = UUID()
        XCTAssertNil(PaneTree.leaf(id).removing(id))
    }

    func testClosingUnknownPaneLeavesLayoutIntact() {
        let tree = PaneTree.split(.vertical, .leaf(UUID()), .leaf(UUID()))
        XCTAssertEqual(tree.removing(UUID()), tree)
    }
}
