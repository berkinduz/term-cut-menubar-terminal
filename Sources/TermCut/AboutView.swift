import SwiftUI

struct AboutContent: View {
    var compact = false
    private let repository = "https://github.com/berkinduz/term-cut-menubar-terminal"
    var body: some View {
        VStack(spacing: compact ? 12 : 18) {
            Image(systemName: "terminal")
                .font(.system(size: compact ? 27 : 36, weight: .light))
                .foregroundStyle(.teal)
                .frame(width: compact ? 64 : 86, height: compact ? 64 : 86)
                .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: compact ? 18 : 23))
            VStack(spacing: 5) {
                Text("term-cut").font(.system(size: compact ? 20 : 24, weight: .semibold, design: .rounded))
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Your terminal. One shortcut away.").foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/berkinduz")!) {
                    Label("Made by berkinduz", systemImage: "person.crop.circle")
                }
                Link(destination: URL(string: "mailto:mberkinduz@gmail.com")!) {
                    Label("mberkinduz@gmail.com", systemImage: "envelope")
                }
                Link(destination: URL(string: repository)!) {
                    Label("Source code & contributions", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }.font(.system(size: 13))
            Link(destination: URL(string: "https://buymeacoffee.com/berkinduz")!) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer")
                    .padding(.horizontal, 8).padding(.vertical, 3)
            }.buttonStyle(.bordered).tint(.teal)
            Text("Free to use. Open to contributions.").font(.caption).foregroundStyle(.secondary)
            if !compact {
                Text("MIT License · Terminal powered by SwiftTerm").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .tint(.teal)
    }
}

final class UtilityWindowController: NSWindowController {
    convenience init<Content: View>(title: String, size: NSSize, content: Content, autosave: String) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = size
        window.setFrameAutosaveName(autosave)
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        window.contentView = host
        window.center()
        self.init(window: window)
    }
    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
