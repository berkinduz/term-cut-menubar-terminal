import AppKit
import QuartzCore
import SwiftUI
import PeekshCore

private final class TerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class TerminalPanelController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    private let workspace: TerminalWorkspace
    private let settings: SettingsStore
    private let placementStore: WindowPlacementStore
    private(set) var isPresented = false
    private var positioning = false
    private var presentationID = 0
    private var stopped = false
    var statusAnchor: (() -> NSRect?)?

    init(workspace: TerminalWorkspace, settings: SettingsStore,
         placementStore: WindowPlacementStore = WindowPlacementStore()) {
        self.workspace = workspace
        self.settings = settings
        self.placementStore = placementStore
        panel = TerminalPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                              styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init()
        panel.title = "Peeksh"
        panel.identifier = NSUserInterfaceItemIdentifier("peeksh-terminal")
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

    func toggle(_ mode: PanelMode = .compact) {
        if isPresented { hide() } else { show(mode) }
    }

    func show(_ mode: PanelMode = .compact) {
        guard !stopped else { return }
        presentationID += 1
        let request = presentationID
        let wasVisible = isPresented
        isPresented = true
        if workspace.active == nil { workspace.addSession() }
        workspace.mode = mode
        positioning = true
        let target = frame()
        updateSizeLimits()
        let animate = settings.value.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if wasVisible && animate {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                guard let self, self.presentationID == request else { return }
                self.positioning = false
            })
        } else {
            panel.setFrame(target, display: true)
            positioning = false
        }
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
        positioning = false
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
        guard !stopped else { return }
        presentationID += 1
        positioning = true
        updateSizeLimits()
        if isPresented {
            panel.setFrame(frame(), display: true)
            panel.alphaValue = 1
        } else { panel.orderOut(nil) }
        positioning = false
    }

    private func updateSizeLimits(screen: NSScreen? = nil) {
        guard let screen = screen ?? targetScreen() else { return }
        let limits = PanelLayout.sizeLimits(mode: .compact, visibleFrame: screen.visibleFrame)
        panel.minSize = limits.minimum
        panel.maxSize = limits.maximum
    }

    private func frame() -> NSRect {
        guard let target = targetScreen() else { return panel.frame }
        let prefs = settings.value
        let size = CGSize(width: prefs.compactWidth, height: prefs.compactHeight)
        if prefs.rememberWindowPosition,
           let saved = placementStore.frame(for: ScreenPlacement.identifier(for: target)) {
            return saved.restored(in: target.visibleFrame, size: size)
        }
        return PanelLayout.frame(mode: .compact, visibleFrame: target.visibleFrame,
                                 anchor: statusAnchor?(), compactSize: size)
    }

    private func targetScreen() -> NSScreen? {
        ScreenPlacement.target(preference: settings.value.screenPreference,
            preferredScreenID: settings.value.preferredScreenID, mode: .compact, anchor: statusAnchor?())
    }

    private func saveFrame() {
        guard !positioning, isPresented, settings.value.rememberWindowPosition,
              let screen = panel.screen else { return }
        placementStore.save(RememberedPanelFrame(frame: panel.frame, visibleFrame: screen.visibleFrame),
                            for: ScreenPlacement.identifier(for: screen))
    }

    func windowDidResignKey(_ notification: Notification) {
        if !settings.value.keepVisible && !workspace.preventsAutoHide { hide() }
    }
    func windowDidUpdate(_ notification: Notification) { workspace.synchronizeFocus(with: panel.firstResponder) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidChangeScreen(_ notification: Notification) {
        guard !positioning, let screen = panel.screen else { return }
        positioning = true
        updateSizeLimits(screen: screen)
        positioning = false
    }
    func windowDidEndLiveResize(_ notification: Notification) {
        guard !positioning, let screen = panel.screen else { return }
        let resizedFrame = panel.frame
        var preferences = settings.value
        preferences.compactWidth = resizedFrame.width
        preferences.compactHeight = resizedFrame.height
        saveFrame()
        settings.value = preferences
        updateSizeLimits(screen: screen)
    }

    func shutdown() {
        stopped = true
        presentationID += 1
        positioning = false
        isPresented = false
        panel.orderOut(nil)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensChanged() { applyPreferences() }
    deinit { NotificationCenter.default.removeObserver(self) }
}
