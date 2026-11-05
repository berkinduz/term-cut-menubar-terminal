import AppKit
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class WindowPlacementTests: XCTestCase {
    func testNativeMaximumResizeMatchesRestoredLayoutWithoutSnapping() async {
        await withController { controller, workspace, settings, _ in
            workspace.addSession(configuration: configuration)
            settings.onChange = { controller.applyPreferences() }
            defer { settings.onChange = nil }
            controller.show()
            guard let screen = controller.panel.screen else { return XCTFail("A display is required") }
            let limits = PanelLayout.sizeLimits(mode: .compact, visibleFrame: screen.visibleFrame)
            XCTAssertEqual(controller.panel.minSize, limits.minimum)
            XCTAssertEqual(controller.panel.maxSize, limits.maximum)
            controller.panel.setFrame(NSRect(origin: controller.panel.frame.origin, size: limits.maximum), display: true)
            let resized = controller.panel.frame.size
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))
            XCTAssertEqual(controller.panel.frame.size, resized)
            controller.hide()
            controller.show()
            XCTAssertEqual(controller.panel.frame.size, limits.maximum)
            controller.panel.maxSize = NSSize(width: 9000, height: 9000)
            controller.applyPreferences()
            XCTAssertEqual(controller.panel.maxSize, limits.maximum)
            controller.panel.maxSize = NSSize(width: 9000, height: 9000)
            controller.windowDidChangeScreen(Notification(name: NSWindow.didChangeScreenNotification))
            XCTAssertEqual(controller.panel.maxSize, limits.maximum)
        }
    }

    func testPlacementPersistsIndependentlyPerDisplayInIsolatedDefaults() {
        let suite = "peeksh-placement-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = RememberedPanelFrame(frame: CGRect(x: 40, y: 50, width: 760, height: 460),
                                         visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950))
        let second = RememberedPanelFrame(frame: CGRect(x: -1800, y: 10, width: 900, height: 600),
                                          visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055))
        let store = WindowPlacementStore(defaults: defaults)
        store.save(first, for: "built-in")
        store.save(second, for: "external")
        let reopened = WindowPlacementStore(defaults: defaults)
        XCTAssertEqual(reopened.frame(for: "built-in"), first)
        XCTAssertEqual(reopened.frame(for: "external"), second)
        XCTAssertNil(WindowPlacementStore().frame(for: "built-in"))
    }

    func testIdleDoesNotCreateSessionsAndToggleRetainsHostAndSession() async {
        await withController { controller, workspace, _, _ in
            controller.applyPreferences()
            XCTAssertTrue(controller.panel.isMovable)
            XCTAssertTrue(controller.panel.styleMask.contains(.resizable))
            XCTAssertFalse(controller.isPresented)
            XCTAssertFalse(controller.panel.isVisible)
            XCTAssertTrue(workspace.sessions.isEmpty)
            let session = workspace.addSession(configuration: configuration)
            let host = controller.panel.contentView
            for _ in 0..<3 {
                controller.toggle()
                XCTAssertTrue(controller.isPresented)
                XCTAssertTrue(controller.panel.contentView === host)
                XCTAssertTrue(workspace.active === session)
                controller.toggle()
                XCTAssertFalse(controller.isPresented)
                XCTAssertFalse(controller.panel.isVisible)
            }
            XCTAssertEqual(workspace.sessions.count, 1)
        }
    }

    func testProgrammaticLayoutPreservesRememberedFramesAndOptOutRestoresAutomaticPlacement() async {
        await withController { controller, workspace, settings, store in
            guard let screen = NSScreen.screens.first else { return XCTFail("A display is required") }
            settings.value.compactWidth = 640
            settings.value.compactHeight = 360
            let remembered = RememberedPanelFrame(
                frame: CGRect(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.minY + 40, width: 640, height: 360),
                visibleFrame: screen.visibleFrame)
            let id = ScreenPlacement.identifier(for: screen)
            store.save(remembered, for: id)
            workspace.addSession(configuration: configuration)
            controller.show()
            XCTAssertEqual(controller.panel.frame, remembered.restored(in: screen.visibleFrame))
            settings.value.compactWidth = 700
            controller.applyPreferences()
            XCTAssertEqual(controller.panel.frame.width, 700)
            XCTAssertEqual(controller.panel.frame.minX, remembered.restored(in: screen.visibleFrame).minX)
            XCTAssertEqual(store.frame(for: id), remembered)
            settings.value.rememberWindowPosition = false
            controller.show()
            let automatic = PanelLayout.frame(mode: .compact, visibleFrame: screen.visibleFrame, anchor: nil,
                compactSize: CGSize(width: settings.value.compactWidth, height: settings.value.compactHeight))
            XCTAssertEqual(controller.panel.frame, automatic)
            XCTAssertEqual(store.frame(for: id), remembered)
        }
    }

    func testAnimatedProgrammaticResizeDoesNotSaveIntermediateFrames() async {
        await withController { controller, workspace, settings, store in
            guard let screen = NSScreen.screens.first else { return XCTFail("A display is required") }
            let id = ScreenPlacement.identifier(for: screen)
            let remembered = RememberedPanelFrame(
                frame: CGRect(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.minY + 40, width: 760, height: 460),
                visibleFrame: screen.visibleFrame)
            store.save(remembered, for: id)
            workspace.addSession(configuration: configuration)
            controller.show()
            settings.value.animationsEnabled = true
            settings.value.compactWidth = 900
            controller.show()
            try? await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertEqual(store.frame(for: id), remembered)
        }
    }

    func testResizeSavesChosenSizeAndRememberOptOutStopsSavingPosition() async {
        await withController { controller, workspace, settings, store in
            workspace.addSession(configuration: configuration)
            controller.show()
            guard let screen = controller.panel.screen else { return XCTFail("A display is required") }
            let id = ScreenPlacement.identifier(for: screen)
            let target = controller.panel.frame.insetBy(dx: 16, dy: 16)
            controller.panel.setFrame(target, display: true)
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))
            XCTAssertEqual(store.frame(for: id)?.frame, target)
            XCTAssertEqual(settings.value.compactWidth, target.width)
            XCTAssertEqual(settings.value.compactHeight, target.height)
            settings.value.rememberWindowPosition = false
            controller.panel.setFrame(target.offsetBy(dx: 10, dy: -10), display: true)
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))
            XCTAssertEqual(store.frame(for: id)?.frame, target)
        }
    }

    func testChosenSizePersistsAcrossSettingsReload() async {
        let suite = "peeksh-resize-relaunch-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        await withController(defaults: defaults) { controller, workspace, settings, _ in
            workspace.addSession(configuration: configuration)
            controller.show()
            let target = controller.panel.frame.insetBy(dx: 16, dy: 16)
            controller.panel.setFrame(target, display: true)
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification))
            controller.hide()
            controller.show()
            XCTAssertEqual(controller.panel.frame.size, target.size)
            let reloadedSettings = SettingsStore(defaults: defaults)
            let reloadedWorkspace = TerminalWorkspace(settings: reloadedSettings)
            reloadedWorkspace.addSession(configuration: configuration)
            let reloaded = TerminalPanelController(workspace: reloadedWorkspace, settings: reloadedSettings)
            defer {
                reloaded.shutdown()
                reloaded.panel.contentView = nil
                reloadedWorkspace.stopAll()
            }
            reloaded.show()
            XCTAssertEqual(reloaded.panel.frame.size, target.size)
        }
    }

    func testAutoHideRespectsPinAndModalInteraction() async {
        await withController { controller, workspace, settings, _ in
            workspace.addSession(configuration: configuration)
            controller.show()
            controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
            XCTAssertTrue(controller.isPresented)
            settings.value.keepVisible = false
            workspace.preventsAutoHide = true
            controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
            XCTAssertTrue(controller.isPresented)
            workspace.preventsAutoHide = false
            controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
            XCTAssertFalse(controller.isPresented)
        }
    }

    func testInterruptedHideCannotCloseReopenedWindowAndShutdownPreventsReopening() async {
        await withController { controller, workspace, settings, _ in
            let session = workspace.addSession(configuration: configuration)
            controller.show()
            settings.value.animationsEnabled = true
            controller.hide()
            controller.show()
            try? await Task.sleep(nanoseconds: 250_000_000)
            XCTAssertTrue(controller.isPresented)
            XCTAssertTrue(controller.panel.isVisible)
            XCTAssertEqual(controller.panel.alphaValue, 1, accuracy: 0.01)
            XCTAssertTrue(workspace.active === session)
            controller.hide()
            controller.shutdown()
            controller.show()
            controller.applyPreferences()
            try? await Task.sleep(nanoseconds: 250_000_000)
            XCTAssertFalse(controller.isPresented)
            XCTAssertFalse(controller.panel.isVisible)
            XCTAssertTrue(workspace.active === session)
            XCTAssertEqual(workspace.mode, .compact)
        }
    }

    private var configuration: ShellConfiguration {
        ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null"
        ], arguments: ["-f"])
    }

    private func withController(defaults suppliedDefaults: UserDefaults? = nil,
        _ body: (TerminalPanelController, TerminalWorkspace, SettingsStore, WindowPlacementStore) async -> Void) async {
        _ = NSApplication.shared
        let suite = "peeksh-window-tests-\(UUID().uuidString)"
        let defaults = suppliedDefaults ?? UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.value.animationsEnabled = false
        settings.value.keepVisible = true
        settings.value.screenPreference = .main
        let workspace = TerminalWorkspace(settings: settings)
        let store = WindowPlacementStore()
        let controller = TerminalPanelController(workspace: workspace, settings: settings, placementStore: store)
        defer {
            controller.shutdown()
            controller.panel.contentView = nil
            workspace.stopAll()
        }
        await body(controller, workspace, settings, store)
    }
}
