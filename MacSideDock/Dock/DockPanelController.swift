import AppKit
import Observation
import SwiftUI

@Observable
final class DockRevealModel {
    var isRevealed: Bool

    init(isRevealed: Bool) {
        self.isRevealed = isRevealed
    }
}

final class DockPanelController {
    private let panel: NSPanel
    private let store: DockConfigStore
    private let runningApps: RunningApplicationsStore
    private let recents: RecentsStore
    private let displayID: CGDirectDisplayID
    private let reveal: DockRevealModel
    private var hostingView: NSHostingView<DockRootView>
    private var hideWorkItem: DispatchWorkItem?

    init(screen: NSScreen, store: DockConfigStore, runningApps: RunningApplicationsStore, recents: RecentsStore) {
        self.store = store
        self.runningApps = runningApps
        self.recents = recents
        self.displayID = screen.displayID
        self.reveal = DockRevealModel(isRevealed: !store.config.shouldAutoHide)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        if let content = panel.contentView {
            content.wantsLayer = true
            content.layer?.masksToBounds = false
            content.clipsToBounds = false
        }
        self.panel = panel

        let root = DockRootView(store: store, runningApps: runningApps, recents: recents, reveal: reveal)
        let hostingView = NSHostingView(rootView: root)
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = false
        hostingView.clipsToBounds = false
        hostingView.autoresizingMask = [.width, .height]
        self.hostingView = hostingView
        panel.contentView = hostingView
        hostingView.layer?.masksToBounds = false
        hostingView.clipsToBounds = false
        applyMousePassthrough()

        applyLayout()
        panel.orderFrontRegardless()
    }

    var screen: NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }

    func close() {
        hideWorkItem?.cancel()
        panel.orderOut(nil)
        panel.close()
    }

    func handleMouse(at point: NSPoint) {
        let autoHide = store.config.shouldAutoHide
        let engaged = isPointerEngaged(at: point)
        let decision = DockRevealLogic.decision(
            state: reveal.isRevealed ? .visible : .hidden,
            event: engaged ? .pointerEngaged : .pointerIdle,
            autoHideEnabled: autoHide
        )
        apply(decision)
        applyMousePassthrough(at: point)
    }

    func applyLayout() {
        if !store.config.shouldAutoHide {
            reveal.isRevealed = true
        }
        let frame = targetFrame()
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        applyMousePassthrough()
    }

    private func apply(_ decision: DockRevealDecision) {
        switch decision {
        case .showImmediately:
            hideWorkItem?.cancel()
            hideWorkItem = nil
            setRevealed(true)
        case .remainVisible:
            hideWorkItem?.cancel()
            hideWorkItem = nil
        case .remainHidden:
            break
        case .scheduleHide:
            scheduleHide()
        case .hideImmediately:
            hideWorkItem?.cancel()
            hideWorkItem = nil
            setRevealed(false)
        }
    }

    private func scheduleHide() {
        guard hideWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.hideWorkItem = nil
            self?.setRevealed(false)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + DockMotion.hideDelay, execute: work)
    }

    private func setRevealed(_ revealed: Bool) {
        if !store.config.shouldAutoHide {
            if !reveal.isRevealed {
                reveal.isRevealed = true
                applyMousePassthrough()
            }
            return
        }
        guard revealed != reveal.isRevealed else { return }
        reveal.isRevealed = revealed
        applyMousePassthrough()
        if revealed {
            DockHaptics.generic()
        }
    }

    private func applyMousePassthrough(at point: NSPoint? = nil) {
        if store.config.shouldAutoHide && !reveal.isRevealed {
            panel.ignoresMouseEvents = true
            return
        }
        if NSEvent.pressedMouseButtons != 0 {
            panel.ignoresMouseEvents = false
            return
        }
        guard reveal.isRevealed, let point else {
            panel.ignoresMouseEvents = false
            return
        }
        panel.ignoresMouseEvents = !interactiveFrame().contains(point)
    }

    private func interactiveFrame() -> NSRect {
        let iconSize = CGFloat(store.config.clampedIconSize)
        let magnification = CGFloat(store.config.clampedMagnification)
        let width = DockLayout.restChromeWidth(iconSize: iconSize)
            + iconSize * (magnification - 1)
            + DockLayout.bleed
        let gutter = DockLayout.restChromeWidth(iconSize: iconSize) + DockLayout.offscreenSlack
        switch store.config.edge {
        case .left:
            return NSRect(
                x: panel.frame.minX + gutter,
                y: panel.frame.minY,
                width: width,
                height: panel.frame.height
            )
        case .right:
            return NSRect(
                x: panel.frame.maxX - gutter - width,
                y: panel.frame.minY,
                width: width,
                height: panel.frame.height
            )
        }
    }

    private func isPointerEngaged(at point: NSPoint) -> Bool {
        guard let screen else { return false }
        let dragging = NSEvent.pressedMouseButtons & (1 << 0) != 0
        let thickness = dragging ? DockMotion.dragEngagementInset : DockMotion.engagementInset
        if reveal.isRevealed, interactiveFrame().insetBy(dx: -DockMotion.engagementInset, dy: -DockMotion.engagementInset).contains(point) {
            return true
        }
        return DockRevealLogic.isPointerEngaged(
            point: point,
            revealed: reveal.isRevealed,
            panelFrame: interactiveFrame(),
            hotEdge: screen.hotEdgeRect(edge: store.config.edge, thickness: thickness),
            inset: thickness
        )
    }

    private func targetFrame() -> NSRect {
        guard let screen else {
            return panel.frame
        }
        let metrics = DockLayout.metrics(
            for: store.config,
            recentsCount: recents.visible(
                excluding: store.config.pinnedApps,
                limit: store.config.recentsLimit
            ).count
        )
        let neighbors = NSScreen.screens
            .filter { $0.displayID != displayID }
            .map(\.frame)
        return DockDisplayLayout.windowFrame(
            screen: screen.frame,
            edge: store.config.edge,
            metrics: metrics,
            otherScreens: neighbors
        )
    }
}

nonisolated enum DockLayout: Sendable {
    struct Metrics {
        var iconSize: CGFloat
        var magnification: CGFloat
        var panelWidth: CGFloat
        var panelHeight: CGFloat
        var restWidth: CGFloat

        var gutter: CGFloat { restWidth + DockLayout.offscreenSlack }
    }

    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 12
    static let iconSpacing: CGFloat = 8
    static let indicatorSize: CGFloat = 5
    static let indicatorGap: CGFloat = 6
    static let nameTagReserve: CGFloat = 280
    static let cornerRadius: CGFloat = 18
    static let bleed: CGFloat = 14
    static let insertionGap: CGFloat = 18
    static let separatorPadding: CGFloat = 8
    static let offscreenSlack: CGFloat = 22
    static let screenInset: CGFloat = 4
    static let screenVerticalMargin: CGFloat = 24

    static var indicatorColumn: CGFloat { indicatorSize + indicatorGap }

    static func iconRestWidth(iconSize: CGFloat) -> CGFloat {
        indicatorColumn + iconSize
    }

    static func restChromeWidth(iconSize: CGFloat) -> CGFloat {
        horizontalPadding * 2 + iconRestWidth(iconSize: iconSize)
    }

    static func iconRowWidth(iconSize: CGFloat, magnification: CGFloat) -> CGFloat {
        iconRestWidth(iconSize: iconSize) + iconSize * (magnification - 1)
    }

    static func panelWidth(iconSize: CGFloat, magnification: CGFloat) -> CGFloat {
        restChromeWidth(iconSize: iconSize)
            + max(iconSize * (magnification - 1) + bleed, nameTagReserve)
    }

    static func magnificationReserve(iconSize: CGFloat, magnification: CGFloat) -> CGFloat {
        iconSize * (magnification - 1) * 3
    }

    static var separatorLength: CGFloat {
        1 + separatorPadding * 2
    }

    static func metrics(for config: DockConfig, recentsCount: Int = 0) -> Metrics {
        let iconSize = CGFloat(config.clampedIconSize)
        let magnification = CGFloat(config.clampedMagnification)
        var count = config.pinnedApps.count
        if config.showRecents && recentsCount > 0 {
            count += recentsCount + 1
        }
        if !config.pinnedFolders.isEmpty {
            count += config.pinnedFolders.count + 1
        }
        count = max(count, 1)
        let extra = DockLayout.magnificationReserve(iconSize: iconSize, magnification: magnification)
        return Metrics(
            iconSize: iconSize,
            magnification: magnification,
            panelWidth: panelWidth(iconSize: iconSize, magnification: magnification),
            panelHeight: verticalPadding * 2 + CGFloat(count) * iconSize + CGFloat(count - 1) * iconSpacing + extra + bleed + insertionGap,
            restWidth: restChromeWidth(iconSize: iconSize)
        )
    }

    /// Ideal fixed window (with off-screen gutter) before multi-display clamping.
    static func unclampedWindowFrame(screen: CGRect, edge: DockEdge, metrics: Metrics) -> CGRect {
        let height = min(metrics.panelHeight, max(0, screen.height - screenVerticalMargin))
        let y = screen.midY - height / 2
        let gutter = metrics.gutter
        let width = metrics.panelWidth + gutter
        switch edge {
        case .left:
            return CGRect(
                x: screen.minX + screenInset - gutter,
                y: y,
                width: width,
                height: height
            )
        case .right:
            return CGRect(
                x: screen.maxX - metrics.panelWidth - screenInset,
                y: y,
                width: width,
                height: height
            )
        }
    }

    /// Single-screen convenience; multi-display callers should use `DockDisplayLayout.windowFrame`.
    static func windowFrame(screen: CGRect, edge: DockEdge, metrics: Metrics) -> CGRect {
        DockDisplayLayout.windowFrame(screen: screen, edge: edge, metrics: metrics)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    func hotEdgeRect(edge: DockEdge, thickness: CGFloat) -> NSRect {
        switch edge {
        case .left:
            return NSRect(x: frame.minX, y: frame.minY, width: thickness, height: frame.height)
        case .right:
            return NSRect(x: frame.maxX - thickness, y: frame.minY, width: thickness, height: frame.height)
        }
    }
}
