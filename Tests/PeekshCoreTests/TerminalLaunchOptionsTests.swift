import XCTest
@testable import PeekshCore

final class TerminalLaunchOptionsTests: XCTestCase {
    func testProfileNamesThatLookLikeOptionsDoNotChangePresentation() throws {
        for name in ["--settings", "--about", "--island", "--compact", "--dropdown"] {
            let launch = try TerminalLaunchOptions(arguments: ["--profile", name])
            XCTAssertEqual(launch.request, .profile(name))
            XCTAssertNil(launch.mode)
            XCTAssertNil(launch.utility)
        }
    }

    func testExplicitPresentationOptionsRemainAvailableAlongsideProfileData() throws {
        let launch = try TerminalLaunchOptions(arguments: ["--island", "--profile", "--settings"])
        XCTAssertEqual(launch.request, .profile("--settings"))
        XCTAssertEqual(launch.mode, .compact)
        XCTAssertNil(launch.utility)
        XCTAssertEqual(try TerminalLaunchOptions(arguments: ["--settings"]).utility, .settings)
        XCTAssertEqual(try TerminalLaunchOptions(arguments: ["--dropdown"]).mode, .compact)
    }
}
