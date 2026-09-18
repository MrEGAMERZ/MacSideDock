import SwiftUI

/// Staggers slide vs. settle with real delays — two `.animation(value:)` modifiers
/// on the same view do not split cleanly when both properties change together.
struct DockRevealChrome<Content: View>: View {
    var isRevealed: Bool
    var edge: DockEdge
    var gutter: CGFloat
    var content: Content

    @State private var visualIsPositioned = false
    @State private var visualIsSettled = false
    @State private var isHovering = false
    @State private var choreographyTask: Task<Void, Never>?

    init(
        isRevealed: Bool,
        edge: DockEdge,
        gutter: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.isRevealed = isRevealed
        self.edge = edge
        self.gutter = gutter
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(
                visualIsSettled ? 1 : DockMotion.collapsedScale,
                anchor: edge == .left ? .leading : .trailing
            )
            .blur(radius: visualIsSettled ? 0 : DockMotion.enterBlur)
            .offset(
                x: DockMotion.hideOffset(
                    isPositioned: visualIsPositioned,
                    edge: edge,
                    gutter: gutter,
                    hovering: isHovering
                )
            )
            .animation(DockMotion.hoverAnimation, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .onAppear {
                visualIsPositioned = isRevealed
                visualIsSettled = isRevealed
            }
            .onChange(of: isRevealed) { _, _ in
                scheduleChoreography()
            }
            .onDisappear {
                choreographyTask?.cancel()
                choreographyTask = nil
            }
    }

    private func scheduleChoreography() {
        let wantPositioned = isRevealed
        let wantSettled = isRevealed
        choreographyTask?.cancel()
        choreographyTask = nil

        let positionChanging = wantPositioned != visualIsPositioned
        let settleChanging = wantSettled != visualIsSettled
        guard positionChanging || settleChanging else { return }

        guard positionChanging && settleChanging else {
            if positionChanging {
                withAnimation(DockMotion.slideAnimation) { visualIsPositioned = wantPositioned }
            } else {
                withAnimation(DockMotion.revealAnimation(entering: wantSettled)) { visualIsSettled = wantSettled }
            }
            return
        }

        if wantPositioned {
            withAnimation(DockMotion.slideAnimation) { visualIsPositioned = true }
            let animation = DockMotion.revealAnimation(entering: true)
            choreographyTask = Task {
                try? await Task.sleep(for: .seconds(DockMotion.enterSettleDelay))
                guard !Task.isCancelled else { return }
                withAnimation(animation) { visualIsSettled = true }
            }
        } else {
            withAnimation(DockMotion.revealAnimation(entering: false)) { visualIsSettled = false }
            let animation = DockMotion.slideAnimation
            choreographyTask = Task {
                try? await Task.sleep(for: .seconds(DockMotion.exitSlideDelay))
                guard !Task.isCancelled else { return }
                withAnimation(animation) { visualIsPositioned = false }
            }
        }
    }
}
