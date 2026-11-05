import AppKit

/// A terminal pulled down from a menu bar, shared by the app and status item.
enum BrandMark {
    static func draw(in rect: NSRect, ink: NSColor, accent: NSColor? = nil, compact: Bool = false) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 100, yBy: rect.height / 100)
        transform.concat()

        let bar = NSBezierPath()
        bar.move(to: NSPoint(x: 6, y: 86))
        if !compact {
            bar.line(to: NSPoint(x: 56, y: 86))
            bar.move(to: NSPoint(x: 80, y: 86))
        }
        bar.line(to: NSPoint(x: 94, y: 86))
        bar.lineWidth = compact ? 8 : 5
        bar.lineCapStyle = .round
        ink.withAlphaComponent(compact ? 1 : 0.55).setStroke()
        bar.stroke()
        if !compact {
            let trigger = NSBezierPath(roundedRect: NSRect(x: 64, y: 82, width: 8, height: 8), xRadius: 4, yRadius: 4)
            (accent ?? ink).setFill()
            trigger.fill()
        }

        let panel = NSBezierPath()
        panel.move(to: NSPoint(x: 56, y: 66))
        panel.line(to: NSPoint(x: 68, y: 76))
        panel.line(to: NSPoint(x: 68, y: 66))
        panel.line(to: NSPoint(x: 80, y: 66))
        panel.curve(to: NSPoint(x: 88, y: 58), controlPoint1: NSPoint(x: 85, y: 66), controlPoint2: NSPoint(x: 88, y: 63))
        panel.line(to: NSPoint(x: 88, y: 18))
        panel.curve(to: NSPoint(x: 80, y: 10), controlPoint1: NSPoint(x: 88, y: 13), controlPoint2: NSPoint(x: 85, y: 10))
        panel.line(to: NSPoint(x: 20, y: 10))
        panel.curve(to: NSPoint(x: 12, y: 18), controlPoint1: NSPoint(x: 15, y: 10), controlPoint2: NSPoint(x: 12, y: 13))
        panel.line(to: NSPoint(x: 12, y: 58))
        panel.curve(to: NSPoint(x: 20, y: 66), controlPoint1: NSPoint(x: 12, y: 63), controlPoint2: NSPoint(x: 15, y: 66))
        panel.line(to: NSPoint(x: 56, y: 66))
        panel.close()
        let outline = compact
            ? NSBezierPath(roundedRect: NSRect(x: 12, y: 10, width: 76, height: 56), xRadius: 8, yRadius: 8)
            : panel
        outline.lineWidth = compact ? 7.5 : 4.5
        outline.lineJoinStyle = .round
        ink.setStroke()
        outline.stroke()

        let prompt = NSBezierPath()
        prompt.move(to: NSPoint(x: 29, y: 49))
        prompt.line(to: NSPoint(x: 41, y: 38))
        prompt.line(to: NSPoint(x: 29, y: 27))
        if !compact {
            prompt.move(to: NSPoint(x: 52, y: 27))
            prompt.line(to: NSPoint(x: 68, y: 27))
        }
        prompt.lineWidth = compact ? 8 : 5.5
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        (accent ?? ink).setStroke()
        prompt.stroke()
    }
}
