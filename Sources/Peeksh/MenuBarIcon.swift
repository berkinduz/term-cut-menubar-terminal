import AppKit

enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            BrandMark.draw(in: rect.insetBy(dx: 0.5, dy: 0.5), ink: .black, compact: true)
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class MenuBarUpdateBadge: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
