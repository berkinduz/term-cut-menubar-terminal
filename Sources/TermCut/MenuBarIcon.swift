import AppKit

enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let prompt = NSBezierPath()
            prompt.lineWidth = 1.6
            prompt.lineCapStyle = .round
            prompt.lineJoinStyle = .round
            prompt.move(to: NSPoint(x: 2.5, y: 6))
            prompt.line(to: NSPoint(x: 6, y: 9))
            prompt.line(to: NSPoint(x: 2.5, y: 12))
            prompt.move(to: NSPoint(x: 8, y: 6))
            prompt.line(to: NSPoint(x: 12, y: 6))
            prompt.stroke()

            let cut = NSBezierPath()
            cut.lineWidth = 1.6
            cut.lineCapStyle = .round
            cut.move(to: NSPoint(x: 9.5, y: 10.5))
            cut.line(to: NSPoint(x: 14.5, y: 15.5))
            cut.move(to: NSPoint(x: 13, y: 10.5))
            cut.line(to: NSPoint(x: 15.5, y: 13))
            cut.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
