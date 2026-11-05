import Foundation

public enum SplitAxis: String, Codable {
    case horizontal
    case vertical
}

public indirect enum PaneTree: Equatable, Codable {
    case leaf(UUID)
    case split(SplitAxis, PaneTree, PaneTree)

    public var leaves: [UUID] {
        switch self {
        case .leaf(let id): return [id]
        case .split(_, let first, let second): return first.leaves + second.leaves
        }
    }

    public func splitting(_ id: UUID, axis: SplitAxis, newPane: UUID) -> PaneTree {
        switch self {
        case .leaf(let existing): return existing == id ? .split(axis, self, .leaf(newPane)) : self
        case .split(let direction, let first, let second):
            return .split(direction, first.splitting(id, axis: axis, newPane: newPane),
                          second.splitting(id, axis: axis, newPane: newPane))
        }
    }

    public func removing(_ id: UUID) -> PaneTree? {
        switch self {
        case .leaf(let existing): return existing == id ? nil : self
        case .split(let axis, let first, let second):
            switch (first.removing(id), second.removing(id)) {
            case (.some(let a), .some(let b)): return .split(axis, a, b)
            case (.some(let a), nil): return a
            case (nil, .some(let b)): return b
            case (nil, nil): return nil
            }
        }
    }
}
