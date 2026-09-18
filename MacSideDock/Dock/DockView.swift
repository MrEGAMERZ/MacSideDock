import AppKit
import SwiftUI

struct DockRootView: View {
    var store: DockConfigStore
    var runningApps: RunningApplicationsStore
    var recents: RecentsStore
    var reveal: DockRevealModel

    var body: some View {
        DockView(store: store, runningApps: runningApps, recents: recents, reveal: reveal)
    }
}

struct DockView: View {
    var store: DockConfigStore
    var runningApps: RunningApplicationsStore
    var recents: RecentsStore
    var reveal: DockRevealModel

    @State private var hoverPoint: CGPoint?
    @State private var urlTargeted = false
    @State private var idTargeted = false
    @State private var insertionIndex: Int?
    @State private var draggingID: String?

    private var dropTargeted: Bool { urlTargeted || idTargeted }

    var body: some View {
        let config = store.config
        let iconSize = CGFloat(config.clampedIconSize)
        let magnification = CGFloat(config.clampedMagnification)
        let influence = DockMagnification.influence(forIconSize: iconSize)
        let edge = config.edge
        let recentIDs = recents.visible(excluding: config.pinnedApps, limit: config.recentsLimit)
        let metrics = DockLayout.metrics(for: config, recentsCount: recentIDs.count)

        DockRevealChrome(isRevealed: reveal.isRevealed, edge: edge, gutter: metrics.gutter) {
            dockBody(
                config: config,
                iconSize: iconSize,
                influence: influence,
                magnification: magnification,
                edge: edge,
                recentIDs: recentIDs
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .left ? .leading : .trailing)
    }

    private func dockBody(
        config: DockConfig,
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        edge: DockEdge,
        recentIDs: [String]
    ) -> some View {
        let chromeWidth = DockLayout.restChromeWidth(iconSize: iconSize)

        return iconColumn(
            config: config,
            iconSize: iconSize,
            influence: influence,
            magnification: magnification,
            edge: edge,
            recentIDs: recentIDs
        )
        .padding(.horizontal, DockLayout.horizontalPadding)
        .padding(.vertical, DockLayout.verticalPadding)
        .frame(width: chromeWidth)
        .background {
            DockGlass()
                .frame(width: chromeWidth)
                .clipShape(RoundedRectangle(cornerRadius: DockLayout.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DockLayout.cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(dropTargeted ? 0.28 : 0.14),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.12), radius: 10, x: edge == .left ? 2 : -2, y: 4)
        }
        .overlay(alignment: edge == .left ? .topLeading : .topTrailing) {
            if let label = hoveredNameLabel(iconSize: iconSize, influence: influence, magnification: magnification) {
                DockNameTag(title: label.title, edge: edge)
                    .offset(
                        x: edge == .left
                            ? chromeWidth + DockMotion.nameTagGap
                            : -(chromeWidth + DockMotion.nameTagGap),
                        y: label.centerY - DockMotion.nameTagHalfHeight
                    )
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "dock")
        .background {
            MouseTrackingView { point in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    hoverPoint = point
                }
            }
        }
        .contextMenu {
            DockBehaviorMenuItems(store: store)
        }
        .dropDestination(for: URL.self, action: { urls, _ in
            let dropped = (urls.isEmpty ? DockDropParser.urlsFromDragPasteboard() : urls)
                .filter { !DockDropParser.isFinderClipping($0) }
            let ok = pin(urls: dropped, appIndex: insertionIndex)
            endDrag()
            return ok
        }, isTargeted: { setURLTargeted($0) })
        .dropDestination(for: DockPinnedAppID.self, action: { items, _ in
            let ok = pinIdentifiers(items.map(\.bundleIdentifier), at: insertionIndex)
            endDrag()
            return ok
        }, isTargeted: { setIDTargeted($0) })
        .onChange(of: hoverPoint?.y) { _, _ in
            refreshInsertion(pinnedIDs: config.pinnedApps.filter { $0 != draggingID })
        }
        .onChange(of: urlTargeted) { _, _ in
            refreshInsertion(pinnedIDs: config.pinnedApps.filter { $0 != draggingID })
        }
        .onChange(of: idTargeted) { _, _ in
            refreshInsertion(pinnedIDs: config.pinnedApps.filter { $0 != draggingID })
        }
        .animation(DockMotion.pressAnimation, value: insertionIndex)
        .animation(DockMotion.revealAnimation(entering: true), value: dropTargeted)
    }

    @ViewBuilder
    private func iconColumn(
        config: DockConfig,
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        edge: DockEdge,
        recentIDs: [String]
    ) -> some View {
        VStack(spacing: DockLayout.iconSpacing) {
            if config.pinnedApps.isEmpty && recentIDs.isEmpty && config.pinnedFolders.isEmpty && insertionIndex == nil {
                emptyState
            } else {
                pinnedSection(
                    ids: config.pinnedApps.filter { $0 != draggingID },
                    iconSize: iconSize,
                    influence: influence,
                    magnification: magnification,
                    edge: edge
                )

                if config.showRecents, !recentIDs.isEmpty {
                    dockSeparator
                    appSection(
                        ids: recentIDs.filter { $0 != draggingID },
                        iconSize: iconSize,
                        influence: influence,
                        magnification: magnification,
                        edge: edge,
                        pinned: false
                    )
                }

                if !config.pinnedFolders.isEmpty {
                    dockSeparator
                    ForEach(config.pinnedFolders) { folder in
                        FolderDockIconView(
                            folder: folder,
                            iconSize: iconSize,
                            scale: scale(for: folder.id, iconSize: iconSize, influence: influence, magnification: magnification),
                            edge: edge,
                            onRemove: { store.unpinFolder(folder.path) },
                            store: store,
                            magnification: magnification
                        )
                    }
                }
            }
        }
    }

    private struct HoveredNameLabel {
        var title: String
        var centerY: CGFloat
    }

    private func hoveredNameLabel(
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat
    ) -> HoveredNameLabel? {
        guard draggingID == nil, !dropTargeted, let hoverPoint else { return nil }
        let rest = restCenterMap(iconSize: iconSize)
        guard let closest = rest.min(by: { abs($0.value - hoverPoint.y) < abs($1.value - hoverPoint.y) }) else {
            return nil
        }
        guard abs(hoverPoint.y - closest.value) < iconSize else { return nil }
        guard !closest.key.hasPrefix("__") else { return nil }

        let title: String
        if let folder = store.config.pinnedFolders.first(where: { $0.id == closest.key }) {
            title = folder.name
        } else {
            title = AppInfoResolver.name(for: closest.key)
        }

        let liveY = liveCenterMap(iconSize: iconSize, influence: influence, magnification: magnification)[closest.key]
            ?? closest.value
        return HoveredNameLabel(title: title, centerY: liveY)
    }

    private var dockSeparator: some View {
        Capsule()
            .fill(Color.white.opacity(0.22))
            .frame(width: 22, height: 1)
            .padding(.vertical, DockLayout.separatorPadding)
            .accessibilityHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.app")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Drop Apps Here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 96)
        .accessibilityLabel("Drop apps or folders here")
    }

    @ViewBuilder
    private func pinnedSection(
        ids: [String],
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        edge: DockEdge
    ) -> some View {
        if insertionIndex == 0 {
            insertionGap
        }
        ForEach(Array(ids.enumerated()), id: \.element) { index, bundleID in
            pinnedIcon(
                bundleID: bundleID,
                iconSize: iconSize,
                influence: influence,
                magnification: magnification,
                edge: edge
            )
            if insertionIndex == index + 1 {
                insertionGap
            }
        }
        if ids.isEmpty, insertionIndex == nil, dropTargeted {
            insertionGap
        }
    }

    private var insertionGap: some View {
        Capsule()
            .fill(Color.white.opacity(0.9))
            .frame(width: 22, height: 2)
            .frame(height: DockLayout.insertionGap)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func appSection(
        ids: [String],
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        edge: DockEdge,
        pinned: Bool
    ) -> some View {
        ForEach(Array(ids.enumerated()), id: \.element) { _, bundleID in
            DockIconView(
                bundleIdentifier: bundleID,
                iconSize: iconSize,
                scale: scale(for: bundleID, iconSize: iconSize, influence: influence, magnification: magnification),
                edge: edge,
                isRunning: runningApps.isRunning(bundleID),
                isFrontmost: runningApps.isFrontmost(bundleID),
                onClick: { AppLaunchService.handleClick(bundleIdentifier: bundleID) },
                onRemove: pinned && store.config.pinnedApps.count > DockConfig.minimumPinnedApps
                    ? { store.unpin(bundleID) }
                    : nil,
                onPin: pinned
                    ? nil
                    : (store.config.pinnedApps.count < DockConfig.maximumPinnedApps
                        ? { store.pin(bundleID) }
                        : nil),
                onLift: { draggingID = $0 },
                showIndicator: store.config.showRunningIndicators,
                store: store
            )
        }
    }

    private func pinnedIcon(
        bundleID: String,
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        edge: DockEdge
    ) -> some View {
        DockIconView(
            bundleIdentifier: bundleID,
            iconSize: iconSize,
            scale: scale(for: bundleID, iconSize: iconSize, influence: influence, magnification: magnification),
            edge: edge,
            isRunning: runningApps.isRunning(bundleID),
            isFrontmost: runningApps.isFrontmost(bundleID),
            onClick: { AppLaunchService.handleClick(bundleIdentifier: bundleID) },
            onRemove: store.config.pinnedApps.count > DockConfig.minimumPinnedApps
                ? { store.unpin(bundleID) }
                : nil,
            onLift: { draggingID = $0 },
            showIndicator: store.config.showRunningIndicators,
            store: store
        )
    }

    private func scale(
        for id: String,
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat
    ) -> CGFloat {
        guard !dropTargeted, let hoverPoint, let center = restCenterMap(iconSize: iconSize)[id] else { return 1 }
        return DockMagnification.scale(
            distance: abs(hoverPoint.y - center),
            influence: influence,
            magnification: magnification
        )
    }

    private func restCenterMap(iconSize: CGFloat) -> [String: CGFloat] {
        axisItems(iconSize: iconSize, influence: 0, magnification: 1, useLiveHeights: false).centers
    }

    private func liveCenterMap(
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat
    ) -> [String: CGFloat] {
        axisItems(iconSize: iconSize, influence: influence, magnification: magnification, useLiveHeights: true).centers
    }

    private func axisItems(
        iconSize: CGFloat,
        influence: CGFloat,
        magnification: CGFloat,
        useLiveHeights: Bool
    ) -> (ids: [String], centers: [String: CGFloat]) {
        let config = store.config
        let pinned = config.pinnedApps.filter { $0 != draggingID }
        let recentIDs = recents.visible(excluding: config.pinnedApps, limit: config.recentsLimit).filter { $0 != draggingID }
        var ids: [String] = []
        var lengths: [CGFloat] = []

        func add(_ id: String, restLength: CGFloat) {
            ids.append(id)
            if useLiveHeights {
                let s = scale(for: id, iconSize: iconSize, influence: influence, magnification: magnification)
                lengths.append(DockMagnification.tileLength(restLength: restLength, scale: s))
            } else {
                lengths.append(restLength)
            }
        }

        if insertionIndex == 0 {
            ids.append("__insert__")
            lengths.append(DockLayout.insertionGap)
        }
        for (index, id) in pinned.enumerated() {
            add(id, restLength: iconSize)
            if insertionIndex == index + 1 {
                ids.append("__insert__")
                lengths.append(DockLayout.insertionGap)
            }
        }
        if config.showRecents, !recentIDs.isEmpty {
            ids.append("__sep-recents__")
            lengths.append(DockLayout.separatorLength)
            recentIDs.forEach { add($0, restLength: iconSize) }
        }
        if !config.pinnedFolders.isEmpty {
            ids.append("__sep-folders__")
            lengths.append(DockLayout.separatorLength)
            config.pinnedFolders.forEach { add($0.id, restLength: iconSize) }
        }

        let centers = DockMagnification.restCenters(
            lengths: lengths,
            spacing: DockLayout.iconSpacing,
            origin: DockLayout.verticalPadding
        )
        var map: [String: CGFloat] = [:]
        for (id, center) in zip(ids, centers) {
            map[id] = center
        }
        return (ids, map)
    }

    @discardableResult
    private func pin(urls: [URL], appIndex: Int? = nil) -> Bool {
        let dropped = (urls.isEmpty ? DockDropParser.urlsFromDragPasteboard() : urls)
            .filter { !DockDropParser.isFinderClipping($0) }
        guard !dropped.isEmpty else { return false }
        var didPin = false
        var nextAppIndex = appIndex ?? store.config.pinnedApps.count
        store.update { config in
            for url in dropped {
                FolderAccess.withSecurityAccess(to: url) { accessible in
                    if let id = AppInfoResolver.bundleIdentifier(forAppURL: accessible) {
                        let before = config.pinnedApps
                        config.pin(id, at: nextAppIndex)
                        if config.pinnedApps != before {
                            didPin = true
                            if !before.contains(id) {
                                nextAppIndex += 1
                            }
                        }
                    } else if let folder = FolderAccess.folder(fromDroppedURL: accessible) {
                        config.pinFolder(folder)
                        didPin = true
                    }
                }
            }
        }
        return didPin
    }

    @discardableResult
    private func pinIdentifiers(_ ids: [String], at appIndex: Int?) -> Bool {
        let valid = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(DockPinnedAppID.isValidBundleID)
        guard !valid.isEmpty else { return false }
        store.update { config in
            var nextIndex = appIndex ?? config.pinnedApps.count
            for id in valid {
                config.pin(id, at: nextIndex)
                nextIndex += 1
            }
        }
        return true
    }

    private func refreshInsertion(pinnedIDs: [String]) {
        guard dropTargeted, let hoverPoint else {
            insertionIndex = nil
            return
        }
        let iconSize = CGFloat(store.config.clampedIconSize)
        let centers = pinnedIDs.compactMap { restCenterMap(iconSize: iconSize)[$0] }
        insertionIndex = DockInsertion.index(for: hoverPoint.y, centers: centers)
    }

    private func setURLTargeted(_ targeted: Bool) {
        urlTargeted = targeted
        if !targeted && !idTargeted {
            insertionIndex = nil
            draggingID = nil
        }
    }

    private func setIDTargeted(_ targeted: Bool) {
        idTargeted = targeted
        if !targeted && !urlTargeted {
            insertionIndex = nil
            draggingID = nil
        }
    }

    private func endDrag() {
        urlTargeted = false
        idTargeted = false
        insertionIndex = nil
        draggingID = nil
    }
}
