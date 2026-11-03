import AppKit
import Darwin
import XCTest
import TermCutCore
@testable import TermCut

@MainActor
final class TerminalCloseTests: XCTestCase {
    private func configuration() -> ShellConfiguration {
        ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null"
        ], arguments: ["-f"])
    }

    private func withWorkspace(_ body: (TerminalWorkspace) async -> Void) async {
        _ = NSApplication.shared
        let suite = "term-cut-close-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let workspace = TerminalWorkspace(settings: SettingsStore(defaults: defaults))
        defer { workspace.onConfirmTermination = nil; workspace.stopAll() }
        await body(workspace)
    }

    private func eventually(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(3)
        while !predicate() && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(predicate(), file: file, line: line)
    }

    private func startJob(in session: TerminalSession) async {
        session.terminal.send(txt: "sleep 30\n")
        await eventually {
            let group = tcgetpgrp(session.terminal.process.childfd)
            return group > 0 && group != session.terminal.process.shellPid
        }
    }

    private func waitForIdleShell(_ session: TerminalSession) async {
        session.terminal.send(txt: "printf '\\033]0;close-test-ready\\007'\n")
        await eventually {
            session.title == "close-test-ready"
                && tcgetpgrp(session.terminal.process.childfd) == session.terminal.process.shellPid
        }
    }

    func testCancellingPaneClosureKeepsTheJobAndWorkspaceIntact() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            await startJob(in: session)
            let tab = workspace.activeTabID
            let root = workspace.activeTab!.root
            var prompts = 0
            workspace.onConfirmTermination = { busy in
                prompts += 1
                XCTAssertEqual(busy.map(\.id), [session.id])
                XCTAssertTrue(workspace.preventsAutoHide)
                return false
            }
            workspace.close(session.id)
            XCTAssertEqual(prompts, 1)
            XCTAssertEqual(workspace.sessions.count, 1)
            XCTAssertEqual(workspace.activeTabID, tab)
            XCTAssertEqual(workspace.activeTab?.root, root)
            XCTAssertTrue(session.terminal.process.running)
            XCTAssertFalse(workspace.preventsAutoHide)
        }
    }

    func testConfirmingPaneClosureStopsTheForegroundProcessGroup() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            await startJob(in: session)
            let group = tcgetpgrp(session.terminal.process.childfd)
            var prompts = 0
            workspace.onConfirmTermination = { _ in prompts += 1; return true }
            workspace.close(session.id)
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(workspace.sessions.isEmpty)
            await eventually { kill(-group, 0) == -1 && errno == ESRCH }
        }
    }

    func testCancellingTabClosureDoesNotPartiallyCloseItsPanes() async {
        await withWorkspace { workspace in
            let first = workspace.addSession(configuration: configuration())
            workspace.split(.horizontal, configuration: configuration())
            let second = workspace.active!
            await startJob(in: second)
            let root = workspace.activeTab!.root
            var prompts = 0
            workspace.onConfirmTermination = { busy in
                prompts += 1
                XCTAssertEqual(busy.map(\.id), [second.id])
                return false
            }
            workspace.closeTab(workspace.activeTabID!)
            XCTAssertEqual(prompts, 1)
            XCTAssertEqual(workspace.activeTab?.root, root)
            XCTAssertTrue(first.terminal.process.running)
            XCTAssertTrue(second.terminal.process.running)
        }
    }

    func testClosingATabPromptsOnceForAllItsRunningPanes() async {
        await withWorkspace { workspace in
            let first = workspace.addSession(configuration: configuration())
            await startJob(in: first)
            workspace.split(.horizontal, configuration: configuration())
            await startJob(in: workspace.active!)
            var prompts = 0
            workspace.onConfirmTermination = { busy in
                prompts += 1
                XCTAssertEqual(busy.count, 2)
                return true
            }
            workspace.closeTab(workspace.activeTabID!)
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(workspace.sessions.isEmpty)
        }
    }

    func testQuitPolicyCanCancelWithoutStoppingAnySession() async {
        await withWorkspace { workspace in
            let first = workspace.addSession(configuration: configuration())
            await startJob(in: first)
            let idle = workspace.addSession(configuration: configuration())
            await waitForIdleShell(idle)
            workspace.onConfirmTermination = { busy in
                XCTAssertEqual(busy.map(\.id), [first.id])
                return false
            }
            XCTAssertFalse(workspace.confirmTermination(of: workspace.sessions))
            XCTAssertTrue(first.terminal.process.running)
            XCTAssertTrue(idle.terminal.process.running)
            workspace.onConfirmTermination = { _ in true }
            XCTAssertTrue(workspace.confirmTermination(of: workspace.sessions))
        }
    }

    func testBackgroundJobsAreProtectedEvenWhenTheShellIsAtItsPrompt() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            session.terminal.send(txt: "sleep 30 &\nprintf '\\033]0;background-ready\\007'\n")
            await eventually { session.title == "background-ready" }
            XCTAssertEqual(tcgetpgrp(session.terminal.process.childfd), session.terminal.process.shellPid)
            var prompts = 0
            workspace.onConfirmTermination = { _ in prompts += 1; return false }
            workspace.close(session.id)
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(session.terminal.process.running)
        }
    }

    func testShellBuiltinActivityIsProtectedWithoutASeparateProcessGroup() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            await eventually { tcgetpgrp(session.terminal.process.childfd) == session.terminal.process.shellPid }
            session.terminal.feed(text: "\u{1b}]7777;start\u{7}")
            var prompts = 0
            workspace.onConfirmTermination = { _ in prompts += 1; return false }
            workspace.close(session.id)
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(session.terminal.process.running)
        }
    }

    func testConfirmingBackgroundJobClosureStopsTheJob() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            session.terminal.send(txt: "sleep 30 &\nprintf '\\033]0;job-%d\\007' $!\n")
            await eventually { session.title.hasPrefix("job-") }
            guard let jobPID = Int32(session.title.dropFirst(4)) else {
                XCTFail("The shell reports its background job PID")
                return
            }
            workspace.onConfirmTermination = { _ in true }
            workspace.close(session.id)
            XCTAssertTrue(workspace.sessions.isEmpty)
            await eventually { kill(jobPID, 0) == -1 && errno == ESRCH }
        }
    }

    func testIdleAndEndedSessionsCloseWithoutPrompting() async {
        await withWorkspace { workspace in
            let idle = workspace.addSession(configuration: configuration())
            await waitForIdleShell(idle)
            workspace.onConfirmTermination = { _ in XCTFail("Idle sessions do not need a prompt"); return false }
            workspace.close(idle.id)
            XCTAssertTrue(workspace.sessions.isEmpty)
            let ended = workspace.addSession(configuration: configuration())
            ended.terminal.send(txt: "exit 0\n")
            await eventually { !ended.isRunning }
            workspace.close(ended.id)
            XCTAssertTrue(workspace.sessions.isEmpty)
        }
    }

    func testBusySessionsStayOpenWithoutAConfirmationHandler() async {
        await withWorkspace { workspace in
            let session = workspace.addSession(configuration: configuration())
            await startJob(in: session)
            workspace.close(session.id)
            XCTAssertEqual(workspace.sessions.count, 1)
            XCTAssertTrue(session.terminal.process.running)
        }
    }

    func testExecReplacingANonintegratedShellStillRequiresConfirmation() async {
        await withWorkspace { workspace in
            let configuration = ShellConfiguration(shell: "/bin/bash", home: "/tmp", inheritedEnvironment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HISTFILE": "/dev/null"
            ], arguments: ["--noprofile", "--norc", "-i"])
            let session = workspace.addSession(configuration: configuration)
            let pid = session.terminal.process.shellPid
            session.terminal.send(txt: "exec /bin/sleep 30\n")
            await eventually {
                var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
                let length = path.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
                return length > 0 && String(cString: path) == "/bin/sleep"
            }
            XCTAssertEqual(tcgetpgrp(session.terminal.process.childfd), pid)
            var prompts = 0
            workspace.onConfirmTermination = { _ in prompts += 1; return false }
            workspace.close(session.id)
            XCTAssertEqual(prompts, 1)
            XCTAssertTrue(session.terminal.process.running)
        }
    }
}
