import AppKit
import SwiftUI

struct DockIconView: View {
    let bundleIdentifier: String
    let iconSize: CGFloat
    let scale: CGFloat
    let edge: DockEdge
    let isRunning: Bool
    let isFrontmost: Bool
    let onClick: () -> Void
    let onRemove: (() -> Void)?
    var onPin: (() -> Void)? = nil
    var onLift: ((String) -> Void)? = nil
    var showIndicator: Bool = true
    var store: DockConfigStore? = nil

    private var name: String {
        AppInfoResolver.name(for: bundleIdentifier)
    }

    /// Vertical slot grows so neighbors push apart. Breadth never changes.
    private var tileHeight: CGFloat {
        DockMagnification.tileLength(restLength: iconSize, scale: scale)
    }

    private var restRowWidth: CGFloat {
        DockLayout.iconRestWidth(iconSize: iconSize)
    }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: DockLayout.indicatorGap) {
                if edge == .left { runningDot }
                iconImage
                if edge == .right { runningDot }
            }
            .frame(width: restRowWidth, height: tileHeight)
        }
        .buttonStyle(DockPressStyle(edge: edge))
        .frame(width: restRowWidth, height: tileHeight)
        .contentShape(Rectangle())
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .onDrag {
            onLift?(bundleIdentifier)
            return DockPinnedAppID.itemProvider(for: bundleIdentifier)
        } preview: {
            Image(nsImage: AppInfoResolver.icon(for: bundleIdentifier))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        }
        .contextMenu {
            Button("Open") { onClick() }
            if isRunning {
                if AppLaunchService.isHidden(bundleIdentifier) {
                    Button("Show") { AppLaunchService.reveal(bundleIdentifier) }
                } else {
                    Button("Hide") { AppLaunchService.hide(bundleIdentifier) }
                }
            }
            Button("Show in Finder") {
                AppLaunchService.revealInFinder(bundleIdentifier)
            }
            Divider()
            Menu("Options") {
                if let onPin {
                    Button("Keep in Dock", action: onPin)
                }
                if let onRemove {
                    Button("Remove from Dock", role: .destructive, action: onRemove)
                }
                if store != nil {
                    Divider()
                    DockBehaviorMenuItems(store: store ?? .shared)
                }
            }
            if let onRemove {
                Divider()
                Button("Remove from Dock", role: .destructive, action: onRemove)
            }
        }
    }

    /// Rest-sized layout slot; scale draws outside so the glass width stays put.
    private var iconImage: some View {
        Image(nsImage: AppInfoResolver.icon(for: bundleIdentifier))
            .resizable()
            .interpolation(.high)
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(scale)
            .frame(width: iconSize, height: tileHeight)
            .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 1)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var runningDot: some View {
        if showIndicator {
            Circle()
                .fill(Color.primary.opacity(isRunning ? (isFrontmost ? 0.88 : 0.48) : 0))
                .frame(width: DockLayout.indicatorSize, height: DockLayout.indicatorSize)
                .animation(.easeInOut(duration: 0.2), value: isRunning)
                .animation(.easeInOut(duration: 0.2), value: isFrontmost)
                .accessibilityHidden(true)
        }
    }
}
