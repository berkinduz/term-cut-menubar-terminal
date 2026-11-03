import AppKit
import SwiftUI
import SwiftTerm
import TermCutCore

struct TerminalWindowView: View {
    @ObservedObject var workspace: TerminalWorkspace
    @ObservedObject var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var theme: TerminalTheme { settings.value.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color(theme.foreground).opacity(0.04)).frame(height: 0.5)
            if let tab = workspace.activeTab {
                PaneTreeView(node: workspace.zoomedPaneID.map { .leaf($0) } ?? tab.root,
                             workspace: workspace, settings: settings,
                             showHeaders: tab.root.leaves.count > 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if settings.value.showStatusBar { footer }
        }
        .background {
            if settings.value.glassEnabled && !reduceTransparency {
                WindowBarMaterial(light: theme == .paper)
                    .overlay(Color(theme.background).opacity(0.20))
                    .allowsHitTesting(false)
            } else {
                Color(theme.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(theme.foreground).opacity(0.12), lineWidth: 1))
        .foregroundStyle(Color(theme.foreground))
        .preferredColorScheme(theme == .paper ? .light : .dark)
        .animation(settings.value.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.18) : nil, value: theme)
    }

    private var header: some View {
        HStack(spacing: 8) {
            tabBar
            Spacer(minLength: 4).frame(width: 8)
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
                Menu {
                    Picker("Window Mode", selection: Binding(get: { workspace.mode }, set: { workspace.onModeChange?($0) })) {
                        ForEach(PanelMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Toggle("Keep visible when switching apps", isOn: $settings.value.keepVisible)
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
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.primary)
            .fixedSize()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(WindowDragArea())
    }

    private func iconButton(_ symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .regular))
                .frame(width: 27, height: 28)
                .foregroundStyle(active ? Color(theme.accent) : Color.primary)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(workspace.tabs) { tab in
                        let session = workspace.session(tab.root.leaves[0])
                        let title = tab.customName ?? session?.compactTitle ?? "Terminal"
                        HStack(spacing: 6) {
                            Button { workspace.selectTab(tab.id) } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: tab.root.leaves.count > 1 ? "rectangle.split.2x1" : "terminal")
                                        .overlay(alignment: .bottomTrailing) {
                                            ActivityDot(activity: workspace.activity(for: tab))
                                                .background(Circle().fill(Color(theme.chrome)).padding(-1))
                                                .offset(x: 2, y: 2)
                                        }
                                    Text(title).lineLimit(1).truncationMode(.middle)
                                }.frame(width: 128, alignment: .leading)
                            }.buttonStyle(.plain).help([tab.customName, session?.titleHelp].compactMap { $0 }.joined(separator: "\n"))
                                .accessibilityAddTraits(tab.id == workspace.activeTabID ? .isSelected : [])
                            Button { workspace.closeTab(tab.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .regular)).frame(width: 18, height: 24)
                            }.buttonStyle(.plain).help("Close tab and its sessions").accessibilityLabel("Close tab")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(tab.id == workspace.activeTabID ? Color(theme.foreground).opacity(0.045) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .contextMenu {
                            Button("Rename Tab…") { rename(tab) }
                            Button("Close Tab") { workspace.closeTab(tab.id) }
                        }
                        .id(tab.id)
                    }
                }
            }
            .onChange(of: workspace.activeTabID) { id in
                if let id { proxy.scrollTo(id, anchor: .trailing) }
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size.width) { _ in
                        if let id = workspace.activeTabID { proxy.scrollTo(id, anchor: .trailing) }
                    }
                }
            }
        }.frame(height: 28)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if let session = workspace.active {
                ActivityDot(activity: session.activity)
                Text(session.activity.description)
                if !session.isRunning {
                    Button("Restart") { workspace.restartActive() }.buttonStyle(.link)
                }
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
    }

    private func rename(_ tab: TerminalTab) {
        workspace.preventsAutoHide = true
        defer { workspace.preventsAutoHide = false }
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.informativeText = "Leave the name empty to use the folder name."
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
                        Text(session.compactTitle).lineLimit(1).truncationMode(.middle).help(session.titleHelp)
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
                    .contentShape(Rectangle())
                    .onTapGesture { workspace.select(id) }
                }
                TerminalHost(session: session).id(id)
                    .onAppear { if workspace.activeID == id { workspace.focusActive() } }
                    .padding(settings.value.terminalPadding)
                    .background(Color(settings.value.theme.background))
                    .overlay(Color(settings.value.theme.background)
                        .opacity(settings.value.dimInactivePanes && workspace.activeID != id ? 0.15 : 0)
                        .allowsHitTesting(false))
            }
        }
        .frame(minWidth: 170, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
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

private struct WindowBarMaterial: NSViewRepresentable {
    let light: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = 1
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
    }
}
