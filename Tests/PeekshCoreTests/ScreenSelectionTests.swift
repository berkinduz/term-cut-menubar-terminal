import XCTest
import CoreGraphics
@testable import PeekshCore

final class ScreenSelectionTests: XCTestCase {
    private let displays = [
        PanelScreen(id: "main", frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
        PanelScreen(id: "external", frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080))
    ]

    func testAutomaticUsesMenuBarAnchor() {
        let anchor = CGRect(x: 1400, y: 950, width: 24, height: 24)
        for mode in PanelMode.allCases {
            let selected = ScreenSelection.screenID(preference: .automatic, preferredScreenID: "",
                mode: mode, screens: displays, mainID: "main", pointer: CGPoint(x: -500, y: 400), anchor: anchor)
            XCTAssertEqual(selected, "main")
        }
    }

    func testFixedMissingDisplayFallsBackToMainAndReconnectRestoresChoice() {
        XCTAssertEqual(select(.fixed, id: "disconnected"), "main")
        XCTAssertEqual(select(.fixed, id: "external"), "external")
        XCTAssertEqual(select(.main), "main")
        XCTAssertEqual(select(.pointer), "external")
    }

    func testNoScreensReturnsNil() {
        XCTAssertNil(ScreenSelection.screenID(preference: .main, preferredScreenID: "", mode: .compact,
                                              screens: [], mainID: nil, pointer: .zero, anchor: nil))
    }

    private func select(_ preference: ScreenPreference, id: String = "") -> String? {
        ScreenSelection.screenID(preference: preference, preferredScreenID: id, mode: .compact,
            screens: displays, mainID: "main", pointer: CGPoint(x: -500, y: 400), anchor: nil)
    }
}
