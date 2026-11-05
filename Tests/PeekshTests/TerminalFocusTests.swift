import AppKit
import SwiftUI
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class TerminalFocusTests: XCTestCase {
    private func configuration() -> ShellConfiguration {
        ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null"
        ], arguments: ["-f"])
    }

    private func withWorkspace(_ body: (TerminalWorkspace, SettingsStore) async -> Void) async {
        _ = NSApplication.shared
        let suite = "peeksh-focus-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        let workspace = TerminalWorkspace(settings: settings)
        workspace.onConfirmTermination = { _ in true }
        defer { workspace.stopAll() }
        await body(workspace, settings)
    }

    func testReturningToATabRestoresItsLastSelectedPane() async {
        await withWorkspace { workspace, _ in
            workspace.addSession(configuration: configuration())
            let firstTab = workspace.activeTabID!
            workspace.split(.horizontal, configuration: configuration())
            let right = workspace.activeID!
            workspace.addSession(configuration: configuration())
            workspace.selectTab(firstTab)
            XCTAssertEqual(workspace.activeID, right)
        }
    }

    func testClickingTheActiveTabKeepsTheFocusedPaneAndZoom() async {
        await withWorkspace { workspace, _ in
            workspace.addSession(configuration: configuration())
            workspace.split(.horizontal, configuration: configuration())
            let right = workspace.activeID!
            workspace.toggleZoom()
            workspace.selectTab(workspace.activeTabID!)
            XCTAssertEqual(workspace.activeID, right)
            XCTAssertEqual(workspace.zoomedPaneID, right)
        }
    }

    func testClosingAnotherTabRestoresTheRemainingTabsSelectedPane() async {
        await withWorkspace { workspace, _ in
            workspace.addSession(configuration: configuration())
            workspace.split(.horizontal, configuration: configuration())
            let right = workspace.activeID!
            workspace.addSession(configuration: configuration())
            workspace.closeTab(workspace.activeTabID!)
            XCTAssertEqual(workspace.activeID, right)
        }
    }

    func testAResponderFromAHiddenTabCannotChangeTheActivePane() async {
        await withWorkspace { workspace, _ in
            let hidden = workspace.addSession(configuration: configuration())
            let active = workspace.addSession(configuration: configuration())
            workspace.synchronizeFocus(with: hidden.terminal)
            XCTAssertEqual(workspace.activeID, active.id)
            XCTAssertTrue(workspace.activeTab!.root.leaves.contains(workspace.activeID!))
        }
    }

    func testNewSplitAndTabSwitchFocusTheMountedTerminal() async {
        await withWorkspace { workspace, settings in
            let first = workspace.addSession(configuration: configuration())
            let firstTab = workspace.activeTabID!
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: TerminalWindowView(workspace: workspace, settings: settings))
            hosting.sizingOptions = []
            window.contentView = hosting
            defer { window.contentView = nil; window.close() }

            await expectFocus(first, in: window)
            workspace.split(.horizontal, configuration: configuration())
            let right = workspace.active!
            await expectFocus(right, in: window)
            workspace.addSession(configuration: configuration())
            await expectFocus(workspace.active!, in: window)
            workspace.selectTab(firstTab)
            await expectFocus(right, in: window)
        }
    }

    func testClosingABackgroundTabKeepsTheActivePaneZoomed() async {
        await withWorkspace { workspace, _ in
            workspace.addSession(configuration: configuration())
            let backgroundTab = workspace.activeTabID!
            workspace.addSession(configuration: configuration())
            workspace.split(.horizontal, configuration: configuration())
            let zoomed = workspace.activeID!
            workspace.toggleZoom()
            workspace.closeTab(backgroundTab)
            XCTAssertEqual(workspace.zoomedPaneID, zoomed)
            XCTAssertEqual(workspace.activeID, zoomed)
        }
    }

    func testClosingANonzoomedSiblingKeepsTheActivePaneZoomed() async {
        await withWorkspace { workspace, _ in
            let sibling = workspace.addSession(configuration: configuration())
            workspace.split(.horizontal, configuration: configuration())
            let zoomed = workspace.activeID!
            workspace.toggleZoom()
            workspace.close(sibling.id)
            XCTAssertEqual(workspace.zoomedPaneID, zoomed)
            XCTAssertEqual(workspace.activeID, zoomed)
        }
    }

    private func expectFocus(_ session: TerminalSession, in window: NSWindow, file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(2)
        while window.firstResponder !== session.terminal && Date() < deadline {
            window.contentView?.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(window.firstResponder === session.terminal, "The selected terminal receives keyboard focus after mounting", file: file, line: line)
    }
}
