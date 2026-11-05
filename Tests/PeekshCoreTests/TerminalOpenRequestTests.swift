import Foundation
import XCTest
@testable import PeekshCore

final class TerminalOpenRequestTests: XCTestCase {
    func testDirectoryURLPreservesSpacesUnicodeAndShellMetacharacters() throws {
        let url = try XCTUnwrap(URL(string: "peeksh://open?path=%2Ftmp%2F%C3%B6rnek%20%24%28touch%20x%29%20%26%20a%2Bb%23c"))
        XCTAssertEqual(try TerminalOpenRequest(url: url), .directory(URL(fileURLWithPath: "/tmp/örnek $(touch x) & a+b#c")))
    }

    func testProfileNameIsDataAndDoesNotRequireADirectory() throws {
        let url = try XCTUnwrap(URL(string: "peeksh://open?profile=frontend%20%26%20backend"))
        XCTAssertEqual(try TerminalOpenRequest(url: url), .profile("frontend & backend"))
    }

    func testAmbiguousOrUnsupportedURLDoesNotOpenAnArbitrarySession() {
        let inputs = ["https://open?path=/tmp", "peeksh://run?path=/tmp", "peeksh://open?path=relative",
                      "peeksh://open?path=/tmp&profile=work", "peeksh://open?path=/tmp&path=/Users",
                      "peeksh://open?profile=%20", "peeksh://open"]
        for value in inputs {
            XCTAssertThrowsError(try TerminalOpenRequest(url: URL(string: value)!), value)
        }
    }

    func testStartupDirectoryArgumentUsesTheSameTypedRequest() throws {
        XCTAssertEqual(try TerminalOpenRequest.from(arguments: ["--compact", "--directory", "/tmp/a b"]),
                       .directory(URL(fileURLWithPath: "/tmp/a b")))
        XCTAssertEqual(try TerminalOpenRequest.from(arguments: ["--profile", "work"]), .profile("work"))
        XCTAssertNil(try TerminalOpenRequest.from(arguments: ["--settings"]))
        XCTAssertThrowsError(try TerminalOpenRequest.from(arguments: ["--directory"]))
        XCTAssertThrowsError(try TerminalOpenRequest.from(arguments: ["--directory", "/tmp", "--profile", "work"]))
    }
}
