import XCTest
@testable import TermCutCore

final class ShellConfigurationTests: XCTestCase {
    func testLoginShellPreservesUserEnvironmentAndAddsTerminalCapabilities() {
        let config = ShellConfiguration(shell: "/bin/bash", home: "/Users/example",
                                        inheritedEnvironment: ["PATH": "/custom/bin:/usr/bin", "LANG": "en_US.UTF-8"])
        XCTAssertEqual(config.executable, "/bin/bash")
        XCTAssertEqual(config.arguments, ["-l"])
        XCTAssertEqual(config.workingDirectory, "/Users/example")
        XCTAssertTrue(config.environment.contains("TERM=xterm-256color"))
        XCTAssertTrue(config.environment.contains("LANG=en_US.UTF-8"))
        XCTAssertTrue(config.environment.contains("PATH=/opt/homebrew/bin:/usr/local/bin:/custom/bin:/usr/bin"))
    }

    func testHomebrewPathIsNotDuplicated() {
        let config = ShellConfiguration(shell: "", home: "/tmp", inheritedEnvironment: ["PATH": "/opt/homebrew/bin:/bin"])
        XCTAssertEqual(config.executable, "/bin/zsh")
        let path = config.environment.first { $0.hasPrefix("PATH=") }!
        XCTAssertEqual(path.components(separatedBy: "/opt/homebrew/bin").count, 2)
    }

    func testZshIntegrationPreservesTheOriginalStartupDirectory() {
        let config = ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: ["ZDOTDIR": "/custom config"],
                                        integrationDirectory: "/application/integration")
        XCTAssertTrue(config.environment.contains("ZDOTDIR=/application/integration"))
        XCTAssertTrue(config.environment.contains("TERM_CUT_ORIGINAL_ZDOTDIR=/custom config"))
        let normal = ShellConfiguration(shell: "/bin/bash", home: "/tmp", inheritedEnvironment: ["ZDOTDIR": "/custom config"],
                                        integrationDirectory: "/application/integration")
        XCTAssertTrue(normal.environment.contains("ZDOTDIR=/custom config"))
        XCTAssertFalse(normal.environment.contains { $0.hasPrefix("TERM_CUT_ORIGINAL_ZDOTDIR=") })
    }
}
