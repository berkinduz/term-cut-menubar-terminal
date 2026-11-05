import AppKit
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class TerminalScrollTests: XCTestCase {
    func testEmptyTerminalHasNoVisibleScrollIndicator() {
        _ = NSApplication.shared
        let session = makeSession()
        defer { session.stop() }
        let indicators = session.terminal.subviews.compactMap { $0 as? NSScroller }
        XCTAssertFalse(indicators.isEmpty)
        XCTAssertTrue(indicators.allSatisfy(\.isHidden))
    }

    func testHistoryStillScrollsWithTheIndicatorHidden() {
        _ = NSApplication.shared
        let session = makeSession()
        defer { session.stop() }
        session.terminal.feed(text: (0..<200).map { "history-\($0)\r\n" }.joined())
        let indicators = session.terminal.subviews.compactMap { $0 as? NSScroller }
        XCTAssertTrue(indicators.allSatisfy(\.isHidden))
        session.terminal.scroll(toPosition: 0)
        XCTAssertEqual(session.terminal.scrollPosition, 0, accuracy: 0.01)
        session.terminal.scroll(toPosition: 1)
        XCTAssertEqual(session.terminal.scrollPosition, 1, accuracy: 0.01)
        let output = String(data: session.terminal.terminal.getBufferAsData(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains("history-0"))
        XCTAssertTrue(output.contains("history-199"))
    }

    private func makeSession() -> TerminalSession {
        let configuration = ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null"
        ], arguments: ["-f"])
        return TerminalSession(configuration: configuration, preferences: AppPreferences())
    }
}
