import CoreGraphics
import Foundation

nonisolated enum DockInsertion: Sendable {
    /// Index in `centers` where a drop at `pointY` should land.
    /// Top half of an icon inserts before it; past the last center appends.
    static func index(for pointY: CGFloat, centers: [CGFloat]) -> Int {
        for (i, center) in centers.enumerated() {
            if pointY < center {
                return i
            }
        }
        return centers.count
    }
}
