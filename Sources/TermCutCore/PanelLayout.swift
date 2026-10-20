import Foundation
import CoreGraphics

public enum PanelMode: String, CaseIterable, Codable {
    case compact
    case dropDown
}

public enum PanelLayout {
    public static func frame(
        mode: PanelMode,
        visibleFrame: CGRect,
        anchor: CGRect?,
        compactSize: CGSize = CGSize(width: 760, height: 460),
        dropDownHeight: Double = 0.5,
        dropDownWidth: Double = 1
    ) -> CGRect {
        let margin: CGFloat = 12
        let availableWidth = max(1, visibleFrame.width - margin * 2)
        let availableHeight = max(1, visibleFrame.height - margin * 2)
        switch mode {
        case .compact:
            let size = CGSize(
                width: min(max(400, compactSize.width), availableWidth),
                height: min(max(260, compactSize.height), availableHeight)
            )
            let idealX = (anchor?.midX ?? visibleFrame.midX) - size.width / 2
            let x = min(max(idealX, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
            return CGRect(x: x, y: visibleFrame.maxY - size.height - margin, width: size.width, height: size.height)
        case .dropDown:
            let fraction = min(max(dropDownHeight, 0.3), 0.9)
            let height = min(max(260, visibleFrame.height * fraction), availableHeight)
            let width = min(max(480, availableWidth * min(max(dropDownWidth, 0.5), 1)), availableWidth)
            return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.maxY - height - margin,
                          width: width, height: height)
        }
    }
}
