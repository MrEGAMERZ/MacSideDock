import Foundation

nonisolated enum DockMagnification: Sendable {
    /// Distance-based scale using a cosine falloff, similar to the system Dock.
    static func scale(distance: CGFloat, influence: CGFloat, magnification: CGFloat) -> CGFloat {
        guard influence > 0, magnification > 1, distance < influence else {
            return 1
        }
        let t = min(max(distance / influence, 0), 1)
        let falloff = 0.5 * (1 + cos(.pi * t))
        return 1 + (magnification - 1) * falloff
    }

    static func influence(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize * 2.6
    }

    /// Rest (unmagnified) centers along the dock axis. Magnification is computed
    /// from these so growing tiles do not chase the cursor.
    static func restCenters(lengths: [CGFloat], spacing: CGFloat, origin: CGFloat) -> [CGFloat] {
        var y = origin
        var centers: [CGFloat] = []
        centers.reserveCapacity(lengths.count)
        for length in lengths {
            centers.append(y + length / 2)
            y += length + spacing
        }
        return centers
    }

    /// Layout length along the dock axis so a magnified icon pushes neighbors
    /// apart. Cross-axis size stays at rest so the glass silhouette stays a pill.
    static func tileLength(restLength: CGFloat, scale: CGFloat) -> CGFloat {
        restLength * max(scale, 1)
    }
}

nonisolated enum DockCoordinateSpace: Sendable {
    /// AppKit views are bottom-left origin. SwiftUI named frames are top-left.
    /// Mapping them 1:1 makes hover magnification pick the opposite icon.
    static func swiftUIPoint(fromAppKit point: CGPoint, height: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: height - point.y)
    }
}
