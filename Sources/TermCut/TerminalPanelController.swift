import AppKit
import QuartzCore
import SwiftUI
import TermCutCore

private final class TerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class TerminalPanelController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    private let workspace: TerminalWorkspace
    private let settings: SettingsStore
    private(set) var isPresented = false
    private var positioning = false
    private var presentationID = 0
    var statusAnchor: (() -> NSRect?)?

    init(workspace: TerminalWorkspace, settings: SettingsStore) {
        self.workspace = workspace
        self.settings = settings
        panel = TerminalPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                              styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        panel.title = "term-cut"
        panel.identifier = NSUserInterfaceItemIdentifier("term-cut-terminal")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 520, height: 300)
        panel.delegate = self
        let hosting = NSHostingView(rootView: TerminalWindowView(workspace: workspace, settings: settings))
        hosting.sizingOptions = []
        panel.contentView = hosting
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func toggle(_ mode: PanelMode) {
        if isPresented && workspace.mode == mode { hide() } else { show(mode) }
    }

    func show(_ mode: PanelMode) {
        presentationID += 1
        let wasVisible = isPresented
        isPresented = true
        if workspace.active == nil { workspace.addSession() }
        workspace.mode = mode
        positioning = true
        let target = frame(for: mode)
        let animate = settings.value.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if wasVisible && animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
        positioning = false
        if !wasVisible { panel.alphaValue = animate ? 0 : 1 }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                panel.animator().alphaValue = 1
            }
        } else { panel.alphaValue = 1 }
        workspace.focusActive()
    }

    func hide() {
        guard isPresented else { return }
        isPresented = false
        presentationID += 1
        let request = presentationID
        if settings.value.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, self.presentationID == request else { return }
                self.panel.orderOut(nil)
            })
        } else { panel.orderOut(nil) }
    }

    func applyPreferences() {
        if isPresented {
            positioning = true
            panel.setFrame(frame(for: workspace.mode), display: true)
            positioning = false
        }
    }

    private func frame(for mode: PanelMode) -> NSRect {
        let anchor = statusAnchor?()
        let screen = mode == .compact
            ? NSScreen.screens.first(where: { screen in anchor.map { $0.intersects(screen.frame) } ?? false })
            : NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        let target = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let prefs = settings.value
        return PanelLayout.frame(mode: mode, visibleFrame: target.visibleFrame, anchor: anchor,
                                 compactSize: CGSize(width: prefs.compactWidth, height: prefs.compactHeight),
                                 dropDownHeight: prefs.dropDownHeight, dropDownWidth: prefs.dropDownWidth)
    }

    func windowDidResignKey(_ notification: Notification) {
        if !settings.value.keepVisible && !workspace.preventsAutoHide { hide() }
    }
    func windowDidUpdate(_ notification: Notification) { workspace.synchronizeFocus(with: panel.firstResponder) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    func windowDidEndLiveResize(_ notification: Notification) {
        guard !positioning, let screen = panel.screen else { return }
        let resizedFrame = panel.frame
        var preferences = settings.value
        if workspace.mode == .compact {
            preferences.compactWidth = resizedFrame.width
            preferences.compactHeight = resizedFrame.height
        } else {
            preferences.dropDownHeight = resizedFrame.height / screen.visibleFrame.height
            preferences.dropDownWidth = resizedFrame.width / (screen.visibleFrame.width - 24)
        }
        settings.value = preferences
    }
    @objc private func screensChanged() { if isPresented { applyPreferences() } }
    deinit { NotificationCenter.default.removeObserver(self) }
}
