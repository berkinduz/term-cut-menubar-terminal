import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 70, y: 70, width: 884, height: 884)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 194, yRadius: 194)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(srgbRed: 0.1, green: 0.13, blue: 0.16, alpha: 1).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.2, blue: 0.23, alpha: 1),
                   ending: NSColor(srgbRed: 0.08, green: 0.1, blue: 0.13, alpha: 1))!
            .draw(in: shape, angle: -90)
        NSColor.white.withAlphaComponent(0.14).setStroke()
        shape.lineWidth = 2
        shape.stroke()
        let glyph = NSBezierPath()
        glyph.move(to: NSPoint(x: 300, y: 630))
        glyph.line(to: NSPoint(x: 435, y: 512))
        glyph.line(to: NSPoint(x: 300, y: 394))
        glyph.lineWidth = 44
        glyph.lineCapStyle = .round
        glyph.lineJoinStyle = .round
        NSColor(srgbRed: 0.58, green: 0.85, blue: 0.76, alpha: 1).setStroke()
        glyph.stroke()
        let underline = NSBezierPath()
        underline.move(to: NSPoint(x: 530, y: 392))
        underline.line(to: NSPoint(x: 710, y: 392))
        underline.lineWidth = 44
        underline.lineCapStyle = .round
        underline.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
