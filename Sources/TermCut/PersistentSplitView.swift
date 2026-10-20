import AppKit
import SwiftUI
import TermCutCore

struct PersistentSplit: NSViewRepresentable {
    let axis: SplitAxis
    let fraction: Double
    let first: AnyView
    let second: AnyView
    let onFractionChanged: (Double) -> Void
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> ProportionalSplitView {
        let view = ProportionalSplitView(axis: axis, fraction: fraction)
        view.addArrangedSubview(host(first))
        view.addArrangedSubview(host(second))
        view.onFractionChanged = onFractionChanged
        return view
    }

    func updateNSView(_ view: ProportionalSplitView, context: Context) {
        (view.arrangedSubviews[0] as? NSHostingView<AnyView>)?.rootView = first
        (view.arrangedSubviews[1] as? NSHostingView<AnyView>)?.rootView = second
        view.onFractionChanged = onFractionChanged
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }

    private func host(_ content: AnyView) -> NSHostingView<AnyView> {
        let view = NSHostingView(rootView: content)
        view.sizingOptions = []
        return view
    }
}

final class ProportionalSplitView: NSSplitView, NSSplitViewDelegate {
    private(set) var fraction: Double
    var onFractionChanged: ((Double) -> Void)?
    private var applyingLayout = false

    init(axis: SplitAxis, fraction: Double) {
        self.fraction = fraction
        super.init(frame: .zero)
        isVertical = axis == .horizontal
        dividerStyle = .thin
        delegate = self
        setAccessibilityLabel("Split terminal panes")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func adjustSubviews() { applyFraction() }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) { applyFraction() }

    private func applyFraction() {
        guard arrangedSubviews.count == 2 else { return }
        let length = isVertical ? bounds.width : bounds.height
        let available = max(0, length - dividerThickness)
        let firstLength = available * fraction
        applyingLayout = true
        if isVertical {
            arrangedSubviews[0].frame = NSRect(x: 0, y: 0, width: firstLength, height: bounds.height)
            arrangedSubviews[1].frame = NSRect(x: firstLength + dividerThickness, y: 0,
                                              width: available - firstLength, height: bounds.height)
        } else {
            arrangedSubviews[0].frame = NSRect(x: 0, y: 0, width: bounds.width, height: firstLength)
            arrangedSubviews[1].frame = NSRect(x: 0, y: firstLength + dividerThickness,
                                              width: bounds.width, height: available - firstLength)
        }
        applyingLayout = false
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !applyingLayout, arrangedSubviews.count == 2 else { return }
        let available = (isVertical ? bounds.width : bounds.height) - dividerThickness
        guard available > 0 else { return }
        fraction = (isVertical ? arrangedSubviews[0].frame.width : arrangedSubviews[0].frame.height) / available
        onFractionChanged?(fraction)
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(isVertical ? 170 : 100, ((isVertical ? bounds.width : bounds.height) - dividerThickness) / 2)
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        let available = (isVertical ? bounds.width : bounds.height) - dividerThickness
        return available - min(isVertical ? 170 : 100, available / 2)
    }
}
