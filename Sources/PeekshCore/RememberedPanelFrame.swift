import Foundation
import CoreGraphics

public struct RememberedPanelFrame: Codable, Equatable {
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    public func restored(in visible: CGRect, size: CGSize? = nil) -> CGRect {
        let margin = PanelLayout.margin
        let size = PanelLayout.sizeLimits(mode: .compact, visibleFrame: visible).clamped(size ?? frame.size)
        let width = size.width
        let height = size.height
        let x = frame.minX - visibleFrame.minX + visible.minX
        let y = frame.minY - visibleFrame.minY + visible.minY
        return CGRect(x: min(max(x, visible.minX + margin), visible.maxX - width - margin),
                      y: min(max(y, visible.minY + margin), visible.maxY - height - margin),
                      width: width, height: height)
    }
}
