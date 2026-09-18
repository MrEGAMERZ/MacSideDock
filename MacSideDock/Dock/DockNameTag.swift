import SwiftUI

/// App name label. Positioned by the dock so every name shares one starting edge
/// next to the glass — short and long titles stay aligned.
struct DockNameTag: View {
    let title: String
    var edge: DockEdge = .left

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(.thickMaterial)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
            .fixedSize(horizontal: true, vertical: true)
            // Keep a stable layout box so left/right docks pin the same edge.
            .frame(
                width: DockLayout.nameTagReserve,
                alignment: edge == .left ? .leading : .trailing
            )
            .clipped()
    }
}
