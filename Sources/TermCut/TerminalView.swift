import AppKit
import SwiftUI
import SwiftTerm
import TermCutCore

struct TerminalWindowView: View {
    @ObservedObject var workspace: TerminalWorkspace
    @ObservedObject var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: TerminalTheme { settings.value.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
            if workspace.tabs.count > 1 { tabBar }
            Rectangle().fill(Color(theme.foreground).opacity(0.07)).frame(height: 1)
            if let tab = workspace.activeTab {
                PaneTreeView(node: workspace.zoomedPaneID.map { .leaf($0) } ?? tab.root,
                             workspace: workspace, settings: settings,
                             showHeaders: tab.root.leaves.count > 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if settings.value.showStatusBar { footer }
        }
        .background(Color(theme.background))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(theme.foreground).opacity(0.12), lineWidth: 1))
        .foregroundStyle(Color(theme.foreground))
        .preferredColorScheme(theme == .paper ? .light : .dark)
        .animation(settings.value.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.18) : nil, value: theme)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "terminal").font(.system(size: 16, weight: .medium)).foregroundStyle(Color(theme.accent))
                Text("term-cut").font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                iconButton("plus", label: "New tab (⌘T)") { workspace.addSession() }
                Menu {
                    Button { workspace.split(.horizontal) } label: { Label("Split Right", systemImage: "rectangle.split.2x1") }
                    Button { workspace.split(.vertical) } label: { Label("Split Down", systemImage: "rectangle.split.1x2") }
                    Divider()
                    Button(workspace.zoomedPaneID == nil ? "Focus Pane" : "Show All Panes") { workspace.toggleZoom() }
                } label: { Image(systemName: "rectangle.split.2x1").frame(width: 27, height: 28) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Split terminal").accessibilityLabel("Split terminal")
                iconButton(settings.value.keepVisible ? "pin.fill" : "pin", label: "Keep visible when switching apps",
                           active: settings.value.keepVisible) { settings.value.keepVisible.toggle(); workspace.focusActive() }
                Menu {
                    Picker("Window Mode", selection: Binding(get: { workspace.mode }, set: { workspace.onModeChange?($0) })) {
                        Text("Compact").tag(PanelMode.compact)
                        Text("Drop-down").tag(PanelMode.dropDown)
                    }
                    .pickerStyle(.menu)
                    Divider()
                    Button("Settings…") { workspace.onSettings?() }
                    Button("About term-cut") { workspace.onAbout?() }
                    Divider()
                    Button("Hide Terminal") { workspace.onHide?() }
                    Button("Quit term-cut") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis").frame(width: 27, height: 28) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("More options").accessibilityLabel("More options")
                iconButton("chevron.up", label: "Hide terminal") { workspace.onHide?() }
            }
            .foregroundStyle(Color(theme.secondary))
            .padding(3)
            .modifier(ControlMaterial(enabled: settings.value.glassEnabled, theme: theme))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(WindowDragArea())
        .background(Color(theme.chrome))
    }

    private func iconButton(_ symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .frame(width: 27, height: 28)
                .foregroundStyle(active ? Color(theme.accent) : Color(theme.secondary))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(workspace.tabs) { tab in
                    HStack(spacing: 8) {
                        Button { workspace.selectTab(tab.id) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: tab.root.leaves.count > 1 ? "rectangle.split.2x1" : "terminal")
                                    .overlay(alignment: .bottomTrailing) {
                                        ActivityDot(activity: workspace.activity(for: tab))
                                            .background(Circle().fill(Color(theme.chrome)).padding(-1))
                                            .offset(x: 2, y: 2)
                                    }
                                Text(tab.customName ?? workspace.session(tab.root.leaves[0])?.title ?? "Terminal")
                                    .lineLimit(1).truncationMode(.middle)
                            }.frame(minWidth: 80, maxWidth: 160, alignment: .leading)
                        }.buttonStyle(.plain)
                        Button { workspace.closeTab(tab.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)).frame(width: 16, height: 20)
                        }.buttonStyle(.plain).help("Close tab and its sessions").accessibilityLabel("Close tab")
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(tab.id == workspace.activeTabID ? Color(theme.foreground).opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .contextMenu {
                        Button("Rename Tab…") { rename(tab) }
                        Button("Close Tab") { workspace.closeTab(tab.id) }
                    }
                }
            }.padding(.horizontal, 12).padding(.bottom, 8)
        }.background(Color(theme.chrome))
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if let session = workspace.active {
                ActivityDot(activity: session.activity)
                Text(session.activity.description)
                if !session.isRunning {
                    Button("Restart") { workspace.restartActive() }.buttonStyle(.link)
                }
                Text("·").opacity(0.5)
                Text(displayDirectory(session.directory)).lineLimit(1).truncationMode(.middle).help(session.directory)
            }
            Spacer()
            if workspace.zoomedPaneID != nil {
                Button("Show all panes") { workspace.toggleZoom() }.buttonStyle(.link)
            }
            if let terminal = workspace.active?.terminal {
                Text("\(terminal.terminal.cols) × \(terminal.terminal.rows)").monospacedDigit()
            }
        }
        .font(.system(size: 10)).foregroundStyle(Color(theme.secondary))
        .padding(.horizontal, 16).frame(height: 28)
        .background(Color(theme.chrome).opacity(0.6))
    }

    private func displayDirectory(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    private func rename(_ tab: TerminalTab) {
        workspace.preventsAutoHide = true
        defer { workspace.preventsAutoHide = false }
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.informativeText = "Leave the name empty to use the shell title."
        let field = NSTextField(string: tab.customName ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { workspace.renameTab(tab.id, name: field.stringValue) }
        workspace.focusActive()
    }
}

private struct PaneTreeView: View {
    let node: PaneTree
    @ObservedObject var workspace: TerminalWorkspace
    @ObservedObject var settings: SettingsStore
    let showHeaders: Bool

    var body: AnyView {
        switch node {
        case .leaf(let id):
            return AnyView(TerminalPaneView(id: id, workspace: workspace, settings: settings, showHeader: showHeaders))
        case .split(let axis, let first, let second):
            let firstView = PaneTreeView(node: first, workspace: workspace, settings: settings, showHeaders: showHeaders)
            let secondView = PaneTreeView(node: second, workspace: workspace, settings: settings, showHeaders: showHeaders)
            let key = "\(axis.rawValue):\(first.leaves[0]):\(second.leaves[0])"
            return AnyView(PersistentSplit(axis: axis, fraction: workspace.splitFraction(for: key),
                                           first: AnyView(firstView), second: AnyView(secondView)) { fraction in
                workspace.saveSplitFraction(fraction, for: key)
            }.id(key))
        }
    }
}

private struct TerminalPaneView: View {
    let id: UUID
    @ObservedObject var workspace: TerminalWorkspace
    @ObservedObject var settings: SettingsStore
    let showHeader: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let session = workspace.session(id) {
                if showHeader {
                    HStack(spacing: 7) {
                        ActivityDot(activity: session.activity).opacity(workspace.activeID == id ? 1 : 0.65)
                        Text(session.title).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button {
                            workspace.select(id); workspace.toggleZoom()
                        } label: {
                            Image(systemName: workspace.zoomedPaneID == id ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        }.help("Focus pane (⇧⌘Return)")
                        .accessibilityLabel(workspace.zoomedPaneID == id ? "Restore split panes" : "Focus pane")
                        Button { workspace.close(id) } label: { Image(systemName: "xmark") }
                            .help("Close pane and stop its session").accessibilityLabel("Close pane")
                    }
                    .font(.system(size: 10)).buttonStyle(.plain)
                    .foregroundStyle(Color(settings.value.theme.secondary))
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(Color(settings.value.theme.chrome).opacity(0.4))
                    .contentShape(Rectangle())
                    .onTapGesture { workspace.select(id) }
                }
                TerminalHost(session: session).id(id)
                    .padding(settings.value.terminalPadding)
                    .overlay(Color(settings.value.theme.background)
                        .opacity(settings.value.dimInactivePanes && workspace.activeID != id ? 0.15 : 0)
                        .allowsHitTesting(false))
            }
        }
        .frame(minWidth: 170, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
        .background(Color(settings.value.theme.background))
    }
}

private struct TerminalHost: NSViewRepresentable {
    let session: TerminalSession
    func makeNSView(context: Context) -> LocalProcessTerminalView { session.terminal }
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

private struct ControlMaterial: ViewModifier {
    let enabled: Bool
    let theme: TerminalTheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), enabled && !reduceTransparency {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(Color(theme.foreground).opacity(0.05), in: Capsule())
        }
    }
}
