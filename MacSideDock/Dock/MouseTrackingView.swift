import AppKit
import QuartzCore
import SwiftUI

struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGPoint?) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
    }
}

final class TrackingNSView: NSView {
    var onMove: ((CGPoint?) -> Void)?

    private var displayLink: CADisplayLink?
    private var lastPoint: CGPoint?
    private var lastHadPoint = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restartDisplayLink()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        restartDisplayLink()
    }

    deinit {
        displayLink?.invalidate()
    }

    private func restartDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil else { return }

        let link = displayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let window else {
            emit(nil)
            return
        }

        let appKitPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.insetBy(dx: -12, dy: -12).contains(appKitPoint) else {
            emit(nil)
            return
        }

        emit(DockCoordinateSpace.swiftUIPoint(fromAppKit: appKitPoint, height: bounds.height))
    }

    private func emit(_ point: CGPoint?) {
        if let point {
            if lastHadPoint, lastPoint == point { return }
            lastHadPoint = true
            lastPoint = point
            onMove?(point)
        } else {
            guard lastHadPoint else { return }
            lastHadPoint = false
            lastPoint = nil
            onMove?(nil)
        }
    }
}
