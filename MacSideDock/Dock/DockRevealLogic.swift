import CoreGraphics
import Foundation

nonisolated enum DockRevealState: Equatable, Sendable {
    case hidden
    case visible
}

nonisolated enum DockRevealEvent: Equatable, Sendable {
    case pointerEngaged
    case pointerIdle
}

nonisolated enum DockRevealDecision: Equatable, Sendable {
    case showImmediately
    case remainVisible
    case remainHidden
    case scheduleHide
    case hideImmediately
}

nonisolated enum DockRevealLogic: Sendable {
    static func decision(
        state: DockRevealState,
        event: DockRevealEvent,
        autoHideEnabled: Bool
    ) -> DockRevealDecision {
        guard autoHideEnabled else {
            return .showImmediately
        }

        switch (state, event) {
        case (.hidden, .pointerEngaged):
            return .showImmediately
        case (.visible, .pointerEngaged):
            return .remainVisible
        case (.visible, .pointerIdle):
            return .scheduleHide
        case (.hidden, .pointerIdle):
            return .remainHidden
        }
    }

    /// While hidden the window still occupies the on-screen dock rect (content is
    /// only offset off-screen). Engagement must use the hot edge then, or the
    /// ghost frame would keep revealing over whatever app sits underneath.
    static func isPointerEngaged(
        point: CGPoint,
        revealed: Bool,
        panelFrame: CGRect,
        hotEdge: CGRect,
        inset: CGFloat
    ) -> Bool {
        if revealed {
            return panelFrame.insetBy(dx: -inset, dy: -inset).contains(point) || hotEdge.contains(point)
        }
        return hotEdge.contains(point)
    }
}
