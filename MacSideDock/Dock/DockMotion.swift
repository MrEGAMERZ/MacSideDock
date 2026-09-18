import AppKit
import SwiftUI

/// Springs and staggered enter/exit, in the same family as Apple’s own island motion:
/// open overshoots slightly, close is critically damped, slide is a straight ease-out.
enum DockMotion {
    static let openSpringResponse: Double = 0.45
    static let openSpringDamping: Double = 0.72
    static let closeSpringResponse: Double = 0.42
    static let closeSpringDamping: Double = 1.0

    static let slideDuration: Double = 0.26
    static let enterSettleDelay: Double = 0.07
    static let exitSlideDelay: Double = 0.08

    static let hoverBump: CGFloat = 0
    static let hoverDuration: Double = 0.18
    static let nameTagGap: CGFloat = 14
    static let nameTagHalfHeight: CGFloat = 14

    static let hideDelay: TimeInterval = 0.28
    static var offscreenSlack: CGFloat { DockLayout.offscreenSlack }
    static let collapsedScale: CGFloat = 0.94
    static let enterBlur: CGFloat = 6
    static let folderPeekDelay: TimeInterval = 0.22
    static let pressScale: CGFloat = 0.88
    static let engagementInset: CGFloat = 6
    static let dragEngagementInset: CGFloat = 28

    static func revealAnimation(entering: Bool) -> Animation {
        entering
            ? .spring(response: openSpringResponse, dampingFraction: openSpringDamping)
            : .spring(response: closeSpringResponse, dampingFraction: closeSpringDamping)
    }

    static var slideAnimation: Animation {
        .easeOut(duration: slideDuration)
    }

    static var hoverAnimation: Animation {
        .easeOut(duration: hoverDuration)
    }

    static var pressAnimation: Animation {
        .spring(response: 0.22, dampingFraction: 0.68)
    }

    static func hideOffset(isPositioned: Bool, edge: DockEdge, gutter: CGFloat, hovering: Bool) -> CGFloat {
        let bump = hovering && isPositioned ? hoverBump : 0
        switch edge {
        case .left:
            return (isPositioned ? gutter : 0) + bump
        case .right:
            return (isPositioned ? -gutter : 0) - bump
        }
    }
}

enum DockHaptics {
    static func generic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}

struct DockPressStyle: ButtonStyle {
    var edge: DockEdge

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DockMotion.pressScale : 1)
            .animation(DockMotion.pressAnimation, value: configuration.isPressed)
    }
}
