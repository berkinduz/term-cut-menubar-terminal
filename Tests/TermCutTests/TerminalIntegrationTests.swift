import AppKit
import XCTest
import TermCutCore
@testable import TermCut

@MainActor
final class TerminalIntegrationTests: XCTestCase {
    private func configuration() -> ShellConfiguration {
        ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null",
            "PS1": "cut-test> ", "LC_ALL": "en_US.UTF-8"
        ], arguments: ["-f"])
    }

    private func eventually(_ description: String, timeout: TimeInterval = 5, _ predicate: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(predicate(), description)
    }

    func testRealPTYInputUnicodeResizeAndExitPreserveOutput() async {
        _ = NSApplication.shared
        let session = TerminalSession(configuration: configuration(), preferences: AppPreferences())
        defer { session.stop() }
        await eventually("Shell starts in a real PTY") { session.terminal.process.running }
        session.terminal.send(txt: "printf 'term-%s-%s\\n' cut verified; printf '\\u2713\\n'; printf '\\033]0;PTY ready\\007'\n")
        await eventually("PTY output reaches the terminal parser") { session.title == "PTY ready" }
        let output = String(data: session.terminal.terminal.getBufferAsData(), encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains("term-cut-verified"))
        XCTAssertTrue(output.contains("✓"))

        session.terminal.setFrameSize(NSSize(width: 500, height: 250))
        var size = winsize()
        let result = ioctl(session.terminal.process.childfd, TIOCGWINSZ, &size)
        XCTAssertEqual(result, 0)
        XCTAssertEqual(Int(size.ws_col), session.terminal.terminal.cols)
        XCTAssertEqual(Int(size.ws_row), session.terminal.terminal.rows)

        session.terminal.send(txt: "sleep 30\n")
        await eventually("Foreground job takes ownership of the PTY") {
            let foreground = tcgetpgrp(session.terminal.process.childfd)
            return foreground > 0 && foreground != session.terminal.process.shellPid
        }
        session.terminal.send([3])
        await eventually("Control-C returns to the shell") {
            tcgetpgrp(session.terminal.process.childfd) == session.terminal.process.shellPid
        }

        session.terminal.send(txt: "vim -u NONE -i NONE -n\n")
        await eventually("A full-screen editor enters its alternate screen") { session.terminal.terminal.isCurrentBufferAlternate }
        session.terminal.send(txt: "\u{1b}:q!\r")
        await eventually("Escape reaches the editor and restores the shell") { !session.terminal.terminal.isCurrentBufferAlternate }

        session.terminal.send(txt: "exit 0\n")
        await eventually("Exit is reported to the session") { !session.isRunning }
        let retainedOutput = String(data: session.terminal.terminal.getBufferAsData(), encoding: .utf8) ?? ""
        XCTAssertTrue(retainedOutput.contains("term-cut-verified"))
    }

    func testSplitsTabsAndPreferenceChangesKeepExistingProcesses() async {
        _ = NSApplication.shared
        let suite = "term-cut-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        let workspace = TerminalWorkspace(settings: settings)
        defer { workspace.stopAll() }
        let first = workspace.addSession(configuration: configuration())
        let firstTab = workspace.activeTabID!
        workspace.split(.horizontal, configuration: configuration())
        let second = workspace.active!
        let originalPID = first.terminal.process.shellPid
        XCTAssertEqual(workspace.activeTab?.root.leaves, [first.id, second.id])
        workspace.toggleZoom()
        XCTAssertEqual(workspace.zoomedPaneID, second.id)
        workspace.toggleZoom()
        XCTAssertNil(workspace.zoomedPaneID)

        workspace.addSession(configuration: configuration())
        XCTAssertEqual(workspace.tabs.count, 2)
        workspace.selectTab(firstTab)
        XCTAssertEqual(workspace.activeID, first.id)
        settings.value.theme = .paper
        settings.value.fontSize = 16
        settings.value.font = .custom
        settings.value.customFontName = "Menlo-Regular"
        workspace.applyPreferences()
        XCTAssertEqual(first.terminal.process.shellPid, originalPID)
        XCTAssertTrue(first.terminal.process.running)
        XCTAssertEqual(first.terminal.font.pointSize, 16)
        XCTAssertEqual(first.terminal.font.fontName, "Menlo-Regular")
        XCTAssertEqual(SettingsStore(defaults: defaults).value.theme, .paper)

        workspace.close(second.id)
        XCTAssertEqual(workspace.activeTab?.root.leaves, [first.id])
        XCTAssertTrue(first.terminal.process.running)
        workspace.closeTab(firstTab)
        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(workspace.sessions.count, 1)
    }

    func testClosingSessionReapsTheShellAndStopsItsForegroundJob() async {
        _ = NSApplication.shared
        let session = TerminalSession(configuration: configuration(), preferences: AppPreferences())
        session.terminal.send(txt: "sleep 30\n")
        await eventually("Foreground job starts before the session closes") {
            let group = tcgetpgrp(session.terminal.process.childfd)
            return group > 0 && group != session.terminal.process.shellPid
        }
        let shellPID = session.terminal.process.shellPid
        let foreground = tcgetpgrp(session.terminal.process.childfd)
        session.stop()
        await eventually("Closing a session reaps its shell instead of leaving a zombie") {
            kill(shellPID, 0) == -1 && errno == ESRCH
        }
        await eventually("Closing a session stops its foreground process group") {
            kill(-foreground, 0) == -1 && errno == ESRCH
        }
    }

    func testZshActivityTracksCommandsWithoutChangingStartupFiles() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("term-cut shell '\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let envFile = "export TERM_CUT_TEST_ENV_LOADED=yes\n"
        let rcFile = "TERM_CUT_TEST_RC_LOADED=yes\nPROMPT='activity-test> '\nprecmd() { return 0 }\n"
        try envFile.write(to: root.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
        try rcFile.write(to: root.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        let config = ShellConfiguration(shell: "/bin/zsh", home: root.path, inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": root.path, "HISTFILE": "/dev/null",
            "TERM_CUT_TEST_ORIGINAL_ZDOTDIR": root.path, "LC_ALL": "en_US.UTF-8"
        ], integrationDirectory: ShellIntegration.zshDirectory)
        let session = TerminalSession(configuration: config, preferences: AppPreferences())
        defer { session.stop() }
        await eventually("The integrated login shell reports its first prompt") { session.activity == .ready }
        session.terminal.send(txt: "if [[ $ZDOTDIR == $TERM_CUT_TEST_ORIGINAL_ZDOTDIR && $TERM_CUT_TEST_ENV_LOADED == yes && $TERM_CUT_TEST_RC_LOADED == yes ]]; then printf '\\033]0;startup-preserved\\007'; fi\n")
        await eventually("Original startup files and ZDOTDIR are preserved") { session.title == "startup-preserved" }

        session.terminal.send(txt: "sleep 30\n")
        await eventually("A foreground command reports running") { session.activity == .running }
        session.terminal.send([3])
        await eventually("An interrupted command reports exit 130") { session.activity == .failed(130) }
        session.terminal.send(txt: "printf 'error text is ordinary output\\n' >&2\n")
        await eventually("Stderr text does not falsely report a failed command") { session.activity == .ready }
        session.terminal.send(txt: "false\n")
        await eventually("Shell builtins report their actual exit status") { session.activity == .failed(1) }
        session.terminal.send(txt: "\n")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(session.activity, .failed(1), "An empty prompt does not clear the last failure")
        session.terminal.send(txt: "true\n")
        await eventually("The next successful command clears the failure") { session.activity == .ready }
        session.terminal.send(txt: "echo )\n")
        await eventually("Syntax errors are reported even when preexec never runs") {
            if case .failed = session.activity { return true }; return false
        }
        session.terminal.send(txt: "exit 7\n")
        await eventually("A nonzero shell exit keeps its decoded status") { !session.isRunning && session.activity == .failed(7) }
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(".zshenv"), encoding: .utf8), envFile)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(".zshrc"), encoding: .utf8), rcFile)
    }

    func testActivityCombinesAcrossHiddenTabsAndClearsWhenAFailedPaneCloses() {
        _ = NSApplication.shared
        let suite = "term-cut-activity-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let workspace = TerminalWorkspace(settings: SettingsStore(defaults: defaults))
        defer { workspace.stopAll() }
        let first = workspace.addSession(configuration: configuration())
        let firstTab = workspace.activeTabID!
        XCTAssertEqual(first.activity, .unavailable)
        first.terminal.feed(text: "\u{1b}]7777;done;2\u{7}")
        workspace.split(.horizontal, configuration: configuration())
        let running = workspace.active!
        for byte in Array("\u{1b}]7777;start\u{1b}\\".utf8) { running.terminal.feed(byteArray: [byte][...]) }
        let other = workspace.addSession(configuration: configuration())
        other.terminal.feed(text: "\u{1b}]7777;done;0\u{7}")
        XCTAssertEqual(workspace.activity, .failed(2))
        XCTAssertEqual(workspace.activity(for: workspace.tabs.first(where: { $0.id == firstTab })!), .failed(2))
        workspace.close(first.id)
        XCTAssertEqual(workspace.activity, .running)
        workspace.close(running.id)
        XCTAssertEqual(workspace.activity, .ready)
    }

    func testDefaultZshStartupRestoresAnUnsetZdotdir() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("term-cut-default-shell-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "TERM_CUT_TEST_HOME_RC=yes\n".write(to: root.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        let config = ShellConfiguration(shell: "/bin/zsh", home: root.path, inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HISTFILE": "/dev/null", "LC_ALL": "en_US.UTF-8"
        ], integrationDirectory: ShellIntegration.zshDirectory)
        let session = TerminalSession(configuration: config, preferences: AppPreferences())
        defer { session.stop() }
        await eventually("The default HOME-based shell reports ready") { session.activity == .ready }
        session.terminal.send(txt: "if [[ -z ${ZDOTDIR+x} && $TERM_CUT_TEST_HOME_RC == yes ]]; then printf '\\033]0;home-startup-preserved\\007'; fi\n")
        await eventually("ZDOTDIR remains unset and the HOME startup file loads") { session.title == "home-startup-preserved" }
    }
}
