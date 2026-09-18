import AppKit
import SwiftUI

struct FolderPeekView: View {
    let folder: PinnedFolder
    let iconSize: CGFloat

    private var url: URL? { FolderAccess.resolve(folder) }

    private var items: [URL] {
        guard let url else { return [] }
        return FolderAccess.contents(of: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(folder.name)
                    .font(.headline)
                Spacer(minLength: 12)
                Button("Open") {
                    if let url { FolderAccess.open(url) }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            if items.isEmpty {
                Text(url == nil ? "This folder isn’t available." : "No Items")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                    ForEach(items, id: \.path) { item in
                        Button {
                            FolderAccess.open(item)
                        } label: {
                            VStack(spacing: 5) {
                                Image(nsImage: FolderAccess.icon(for: item))
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                Text(DisplayName.withoutExtension(item.lastPathComponent))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 64)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(item.lastPathComponent)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 268)
    }
}

struct FolderDockIconView: View {
    let folder: PinnedFolder
    let iconSize: CGFloat
    let scale: CGFloat
    let edge: DockEdge
    let onRemove: () -> Void
    var store: DockConfigStore? = nil
    var magnification: CGFloat = 1.8

    @State private var peeking = false
    @State private var peekTask: Task<Void, Never>?

    private var tileHeight: CGFloat {
        DockMagnification.tileLength(restLength: iconSize, scale: scale)
    }

    private var restRowWidth: CGFloat {
        DockLayout.iconRestWidth(iconSize: iconSize)
    }

    var body: some View {
        let url = FolderAccess.resolve(folder)
        Button {
            if let url { FolderAccess.open(url) }
        } label: {
            Image(nsImage: url.map(FolderAccess.icon(for:)) ?? NSImage(named: NSImage.folderName) ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(scale)
                .frame(width: restRowWidth, height: tileHeight)
                .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
        }
        .buttonStyle(DockPressStyle(edge: edge))
        .frame(width: restRowWidth, height: tileHeight)
        .contentShape(Rectangle())
        .onHover { hovering in
            peekTask?.cancel()
            peekTask = nil
            if hovering {
                peekTask = Task {
                    try? await Task.sleep(for: .seconds(DockMotion.folderPeekDelay))
                    guard !Task.isCancelled else { return }
                    peeking = true
                    DockHaptics.generic()
                }
            } else {
                peeking = false
            }
        }
        .onDisappear {
            peekTask?.cancel()
            peekTask = nil
        }
        .popover(isPresented: $peeking, arrowEdge: edge == .left ? .trailing : .leading) {
            FolderPeekView(folder: folder, iconSize: iconSize)
        }
        .contextMenu {
            Button("Open") {
                if let url { FolderAccess.open(url) }
            }
            Button("Show in Finder") {
                if let url { FolderAccess.open(url) }
            }
            Divider()
            Menu("Options") {
                Button("Remove from Dock", role: .destructive, action: onRemove)
                if store != nil {
                    Divider()
                    DockBehaviorMenuItems(store: store ?? .shared)
                }
            }
            Divider()
            Button("Remove from Dock", role: .destructive, action: onRemove)
        }
    }
}
