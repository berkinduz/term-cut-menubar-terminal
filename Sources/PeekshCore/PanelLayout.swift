import Foundation
import CoreGraphics

public enum PanelMode: String, CaseIterable, Codable {
    case compact

    public init?(savedValue: String) {
        if savedValue == "dropDown" || savedValue == "island" { self = .compact }
        else if let mode = Self(rawValue: savedValue) { self = mode }
        else { return nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let mode = Self(savedValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown window mode: \(value)")
        }
        self = mode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum ScreenPreference: String, CaseIterable, Codable {
    case automatic
    case pointer
    case main
    case fixed
}

public struct PanelSizeLimits {
    public let minimum: CGSize
    public let maximum: CGSize
    func clamped(_ size: CGSize) -> CGSize {
        CGSize(width: min(max(minimum.width, size.width), maximum.width),
               height: min(max(minimum.height, size.height), maximum.height))
    }
}

public enum PanelLayout {
    static let margin: CGFloat = 12

    public static func sizeLimits(mode: PanelMode, visibleFrame: CGRect) -> PanelSizeLimits {
        let maximum = CGSize(width: max(1, visibleFrame.width - margin * 2),
                             height: max(1, visibleFrame.height - margin * 2))
        return PanelSizeLimits(minimum: CGSize(width: min(520, maximum.width), height: min(300, maximum.height)),
                               maximum: maximum)
    }

    public static func frame(mode: PanelMode, visibleFrame: CGRect, anchor: CGRect?,
                             compactSize: CGSize = CGSize(width: 760, height: 460)) -> CGRect {
        let size = sizeLimits(mode: mode, visibleFrame: visibleFrame).clamped(compactSize)
        let idealX = (anchor?.midX ?? visibleFrame.midX) - size.width / 2
        let x = min(max(idealX, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        return CGRect(x: x, y: visibleFrame.maxY - size.height - margin, width: size.width, height: size.height)
    }
}
