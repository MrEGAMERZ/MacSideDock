import CoreGraphics
import Foundation

/// One secondary dock per display, all on the same Settings edge.
/// Window frames must never spill onto a neighbor — that is how a laptop’s
/// right dock was appearing on the left of an external monitor.
nonisolated enum DockDisplayLayout: Sendable {
    struct Screen: Equatable, Sendable {
        var id: UInt32
        var frame: CGRect
    }

    static func uniqueScreens(_ screens: [Screen]) -> [Screen] {
        var seenIDs = Set<UInt32>()
        var seenFrames: [CGRect] = []
        var result: [Screen] = []
        result.reserveCapacity(screens.count)
        for screen in screens {
            let frame = screen.frame.integral
            if seenFrames.contains(where: { framesMatch($0, frame) }) {
                continue
            }
            if screen.id != 0 {
                if !seenIDs.insert(screen.id).inserted { continue }
            }
            seenFrames.append(frame)
            result.append(Screen(id: screen.id, frame: screen.frame))
        }
        return result
    }

    static func windowFrame(
        screen: CGRect,
        edge: DockEdge,
        metrics: DockLayout.Metrics,
        otherScreens: [CGRect] = []
    ) -> CGRect {
        var frame = DockLayout.unclampedWindowFrame(screen: screen, edge: edge, metrics: metrics)
        guard !otherScreens.isEmpty else { return frame }

        for other in otherScreens where !framesMatch(other, screen) {
            let overlap = frame.intersection(other)
            guard overlap.width > 0.5, overlap.height > 1 else { continue }
            switch edge {
            case .left:
                frame.origin.x += overlap.width
                frame.size.width = max(0, frame.width - overlap.width)
            case .right:
                frame.size.width = max(0, frame.width - overlap.width)
            }
        }

        let minimumWidth = metrics.panelWidth
        if frame.width + 0.5 < minimumWidth || frame.width <= 0 {
            return clampedToScreen(screen: screen, edge: edge, metrics: metrics)
        }
        return frame
    }

    static func framesOverlap(_ a: CGRect, _ b: CGRect) -> Bool {
        let hit = a.intersection(b)
        return hit.width > 0.5 && hit.height > 1
    }

    private static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1
            && abs(a.minY - b.minY) < 1
            && abs(a.width - b.width) < 1
            && abs(a.height - b.height) < 1
    }

    private static func clampedToScreen(screen: CGRect, edge: DockEdge, metrics: DockLayout.Metrics) -> CGRect {
        let height = min(metrics.panelHeight, max(0, screen.height - DockLayout.screenVerticalMargin))
        let y = screen.midY - height / 2
        let maxWidth = max(metrics.panelWidth, screen.width - DockLayout.screenInset)
        let width = min(metrics.panelWidth + metrics.gutter, maxWidth)
        switch edge {
        case .left:
            return CGRect(x: screen.minX + DockLayout.screenInset, y: y, width: width, height: height)
        case .right:
            return CGRect(x: screen.maxX - width - DockLayout.screenInset, y: y, width: width, height: height)
        }
    }
}
