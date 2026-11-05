import XCTest
@testable import PeekshCore

final class CommandCompletionPolicyTests: XCTestCase {
    func testOnlyLongCommandsFinishingWhileHiddenNotifyWhenEnabled() {
        XCTAssertTrue(CommandCompletionPolicy.shouldNotify(enabled: true, terminalVisible: false, duration: 10, minimumDuration: 10))
        XCTAssertFalse(CommandCompletionPolicy.shouldNotify(enabled: false, terminalVisible: false, duration: 30, minimumDuration: 10))
        XCTAssertFalse(CommandCompletionPolicy.shouldNotify(enabled: true, terminalVisible: true, duration: 30, minimumDuration: 10))
        XCTAssertFalse(CommandCompletionPolicy.shouldNotify(enabled: true, terminalVisible: false, duration: 9.99, minimumDuration: 10))
    }
}
