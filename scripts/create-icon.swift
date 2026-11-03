import AppKit

@main
enum CreateIcon {
    static func main() throws {
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
                NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
                drawIcon()
                NSGraphicsContext.restoreGraphicsState()
                let suffix = scale == 2 ? "@2x" : ""
                try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
    }

    private static func drawIcon() {
        let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        NSColor(srgbRed: 0.12, green: 0.11, blue: 0.10, alpha: 1).setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.21, blue: 0.19, alpha: 1),
                   ending: NSColor(srgbRed: 0.10, green: 0.095, blue: 0.09, alpha: 1))!.draw(in: tile, angle: -90)
        NSColor.white.withAlphaComponent(0.13).setStroke()
        tile.lineWidth = 2
        tile.stroke()
        BrandMark.draw(in: NSRect(x: 186, y: 196, width: 652, height: 652),
                       ink: NSColor(srgbRed: 0.83, green: 0.83, blue: 0.78, alpha: 1),
                       accent: NSColor(srgbRed: 0.78, green: 0.66, blue: 0.45, alpha: 1))
    }
}
