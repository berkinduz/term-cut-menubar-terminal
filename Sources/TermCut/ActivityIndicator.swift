import AppKit
import SwiftUI
import TermCutCore

extension TerminalActivity {
    var color: NSColor {
        switch self {
        case .ready: return .systemGreen
        case .running: return .systemYellow
        case .failed: return .systemRed
        case .unavailable, .ended: return .secondaryLabelColor
        }
    }
}

struct ActivityDot: View {
    let activity: TerminalActivity

    var body: some View {
        Circle().fill(Color(activity.color)).frame(width: 5, height: 5)
            .help(activity.description)
            .accessibilityLabel(activity.description)
    }
}

final class MenuBarActivityDot: NSView {
    var activity: TerminalActivity = .ended {
        didSet { if oldValue != activity { needsDisplay = true } }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        activity.color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
    }
}
