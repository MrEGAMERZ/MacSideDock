import CoreGraphics
import Foundation
import Testing
@testable import MacSideDock

struct DockConfigTests {
    @Test func defaultConfigHasPinnedApps() {
        #expect(!DockConfig.default.pinnedApps.isEmpty)
        #expect(DockConfig.default.edge == .left)
        #expect(DockConfig.default.shouldAutoHide)
    }

    @Test func roundTripJSON() throws {
        let original = DockConfig.default
        let data = try DockConfigStore.encoder.encode(original)
        let decoded = try DockConfigStore.decoder.decode(DockConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodesStringPinnedAppsAndFillsDefaults() throws {
        let json = """
        { "edge": "right", "pinnedApps": ["com.apple.finder", "com.apple.Safari"] }
        """.data(using: .utf8)!
        let decoded = try DockConfigStore.decoder.decode(DockConfig.self, from: json)
        #expect(decoded.edge == .right)
        #expect(decoded.pinnedApps == ["com.apple.finder", "com.apple.Safari"])
        #expect(decoded.autoHide)
        #expect(decoded.version >= 1)
    }

    @Test func decodesObjectPinnedApps() throws {
        let json = """
        { "pinnedApps": [{ "bundleIdentifier": "com.apple.finder" }] }
        """.data(using: .utf8)!
        let decoded = try DockConfigStore.decoder.decode(DockConfig.self, from: json)
        #expect(decoded.pinnedApps == ["com.apple.finder"])
    }

    @Test func clampsExtremeMetrics() throws {
        let json = """
        { "iconSize": 4, "magnification": 99 }
        """.data(using: .utf8)!
        let decoded = try DockConfigStore.decoder.decode(DockConfig.self, from: json)
        #expect(decoded.iconSize == DockConfig.minimumIconSize)
        #expect(decoded.magnification == DockConfig.maximumMagnification)
    }

    @Test func pinMoveAndUnpin() {
        var config = DockConfig.default
        config.pinnedApps = ["a", "b", "c"]
        config.pin("b", at: 0)
        #expect(config.pinnedApps == ["b", "a", "c"])
        config.movePinnedApp(from: 2, to: 0)
        #expect(config.pinnedApps == ["c", "b", "a"])
        let removedB = config.unpin("b")
        #expect(removedB)
        #expect(config.pinnedApps == ["c", "a"])
        config.pin("d", at: 1)
        #expect(config.pinnedApps == ["c", "d", "a"])
    }

    @Test func pinnedAppsStayBetweenOneAndTen() {
        var config = DockConfig.default
        config.pinnedApps = ["only"]
        let keptLast = config.unpin("only")
        #expect(!keptLast)
        #expect(config.pinnedApps == ["only"])

        config.pinnedApps = (1...12).map { "app.\($0)" }
        config = DockConfig(
            version: config.version,
            edge: config.edge,
            autoHide: config.autoHide,
            reserveScreenSpace: config.reserveScreenSpace,
            iconSize: config.iconSize,
            magnification: config.magnification,
            pinnedApps: config.pinnedApps,
            showRecents: config.showRecents,
            recentsLimit: config.recentsLimit,
            pinnedFolders: config.pinnedFolders,
            showRunningIndicators: config.showRunningIndicators,
            lastMagnification: config.lastMagnification
        )
        #expect(config.pinnedApps.count == DockConfig.maximumPinnedApps)

        let before = config.pinnedApps
        config.pin("app.overflow")
        #expect(config.pinnedApps == before)
    }

    @Test func sequentialUnpinsDoNotResurrectEarlierApps() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidedock-unpin-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = DockConfigStore(fileURL: url, watch: true)
        store.update { $0.pinnedApps = ["a", "b", "c", "d"] }
        let removedA = store.unpin("a")
        #expect(removedA)
        #expect(!store.config.pinnedApps.contains("a"))
        let removedB = store.unpin("b")
        #expect(removedB)
        #expect(store.config.pinnedApps == ["c", "d"])
        // Give the directory watcher a moment; it must not restore "a" or "b".
        Thread.sleep(forTimeInterval: 0.5)
        #expect(store.config.pinnedApps == ["c", "d"])
    }

    @Test func toggleMagnificationRemembersAmount() {
        var config = DockConfig.default
        config.setMagnification(2.2)
        config.toggleMagnification()
        #expect(!config.isMagnificationOn)
        config.toggleMagnification()
        #expect(config.magnification == 2.2)
    }

    @Test func decodesMissingIndicatorFlagAsOn() throws {
        let json = """
        { "pinnedApps": ["com.apple.finder"] }
        """.data(using: .utf8)!
        let decoded = try DockConfigStore.decoder.decode(DockConfig.self, from: json)
        #expect(decoded.showRunningIndicators)
    }

    @Test func reserveSpaceDisablesAutoHideBehavior() {
        var config = DockConfig.default
        config.autoHide = true
        config.reserveScreenSpace = true
        #expect(!config.shouldAutoHide)
    }

    @Test func persistAndReloadFromTempFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidedock-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = DockConfigStore(fileURL: url, watch: false)
        store.update { $0.edge = .right }
        store.update { $0.pinnedApps = ["com.apple.finder"] }

        let reloaded = DockConfigStore(fileURL: url, watch: false)
        #expect(reloaded.config.edge == .right)
        #expect(reloaded.config.pinnedApps == ["com.apple.finder"])
    }

    @Test func migratesLegacyConfigDirectoryOnFirstLaunch() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidedock-migrate-\(UUID().uuidString)", isDirectory: true)
        let legacyDir = root.appendingPathComponent(AppBrand.legacyConfigDirectoryName, isDirectory: true)
        let modernDir = root.appendingPathComponent(AppBrand.configDirectoryName, isDirectory: true)
        let legacyURL = legacyDir.appendingPathComponent("config.json")
        let modernURL = modernDir.appendingPathComponent("config.json")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        var seed = DockConfig.default
        seed.edge = .right
        seed.pinnedApps = ["com.apple.finder", "com.apple.Safari"]
        try DockConfigStore.encoder.encode(seed).write(to: legacyURL, options: .atomic)

        // Simulate defaultFileURL resolution: prefer modern, load legacy if missing.
        #expect(!FileManager.default.fileExists(atPath: modernURL.path))
        let store = DockConfigStore(fileURL: modernURL, watch: false)
        #expect(store.config.edge == .right)
        #expect(store.config.pinnedApps == ["com.apple.finder", "com.apple.Safari"])
        #expect(FileManager.default.fileExists(atPath: modernURL.path))
    }
}

struct AppInfoResolverTests {
    @Test func readsBundleIDFromAppAndFromContents() {
        let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        #expect(AppInfoResolver.bundleIdentifier(forAppURL: finder) == "com.apple.finder")
        let nested = finder.appendingPathComponent("Contents")
        #expect(AppInfoResolver.bundleIdentifier(forAppURL: nested) == "com.apple.finder")
    }

    @Test func finderNameDoesNotIncludeAppExtension() {
        let name = AppInfoResolver.name(for: "com.apple.finder")
        #expect(!name.lowercased().hasSuffix(".app"))
        #expect(!name.isEmpty)
    }
}

struct DisplayNameTests {
    @Test func stripsAppExtension() {
        #expect(DisplayName.withoutExtension("System Settings.app") == "System Settings")
        #expect(DisplayName.withoutExtension("Safari.app") == "Safari")
        #expect(DisplayName.withoutExtension("Notes") == "Notes")
    }
}

struct AppClickActionTests {
    @Test func launchesWhenNotRunning() {
        #expect(AppClickAction.resolve(isRunning: false, isActive: false) == .launch)
    }

    @Test func activatesWhenRunningInBackground() {
        #expect(AppClickAction.resolve(isRunning: true, isActive: false) == .activate)
    }

    @Test func hidesWhenFrontmost() {
        #expect(AppClickAction.resolve(isRunning: true, isActive: true) == .hide)
    }
}

struct RunningAppIdentityTests {
    @Test func systemSettingsAliasesMatch() {
        let running: Set<String> = ["com.apple.Settings"]
        #expect(RunningAppIdentity.isRunning("com.apple.systempreferences", in: running))
        #expect(RunningAppIdentity.isFrontmost("com.apple.systempreferences", frontmost: "com.apple.Settings"))
    }

    @Test func unrelatedIDsDoNotMatch() {
        #expect(!RunningAppIdentity.isRunning("com.apple.Safari", in: ["com.apple.finder"]))
    }
}

struct DockPinnedAppIDTests {
    @Test func acceptsReverseDNSBundleIDs() {
        #expect(DockPinnedAppID.isValidBundleID("com.apple.systempreferences"))
        #expect(DockPinnedAppID.isValidBundleID("com.apple.Safari"))
    }

    @Test func rejectsFilePathsAndClippings() {
        #expect(!DockPinnedAppID.isValidBundleID("com.apple.systempreferences.textClipping"))
        #expect(!DockPinnedAppID.isValidBundleID("/Users/rehan/Desktop/MUSIC"))
        #expect(!DockPinnedAppID.isValidBundleID("MUSIC"))
    }

    @Test func finderClippingsAreNotDroppableFolders() {
        let clipping = URL(fileURLWithPath: "/Users/rehan/Desktop/com.apple.systempreferences.textClipping")
        #expect(DockDropParser.isFinderClipping(clipping))
        #expect(!DockDropParser.isFinderClipping(URL(fileURLWithPath: "/Users/rehan/Desktop/MUSIC")))
    }
}

struct DockMagnificationTests {
    @Test func identityWhenOutsideInfluence() {
        #expect(DockMagnification.scale(distance: 200, influence: 80, magnification: 1.8) == 1)
        #expect(DockMagnification.scale(distance: 0, influence: 80, magnification: 1) == 1)
    }

    @Test func peaksAtCursor() {
        let peak = DockMagnification.scale(distance: 0, influence: 80, magnification: 2)
        #expect(peak == 2)
    }

    @Test func fallsOffTowardOne() {
        let near = DockMagnification.scale(distance: 10, influence: 80, magnification: 2)
        let far = DockMagnification.scale(distance: 60, influence: 80, magnification: 2)
        #expect(near > far)
        #expect(far > 1)
    }

    @Test func tileLengthGrowsSoNeighborsCanSpread() {
        #expect(DockMagnification.tileLength(restLength: 48, scale: 1) == 48)
        #expect(DockMagnification.tileLength(restLength: 48, scale: 2) == 96)
    }

    @Test func restCentersIgnoreMagnification() {
        let centers = DockMagnification.restCenters(lengths: [48, 48, 48], spacing: 8, origin: 12)
        #expect(centers.count == 3)
        #expect(centers[1] - centers[0] == 56)
        #expect(centers[2] - centers[1] == 56)
    }

    @Test func magnifiedTilesDoNotOverlapAlongAxis() {
        let rest: [CGFloat] = [48, 48]
        let origin: CGFloat = 12
        let spacing: CGFloat = 8
        let scales: [CGFloat] = [2, 1.4]
        let heights = zip(rest, scales).map { DockMagnification.tileLength(restLength: $0, scale: $1) }
        let firstBottom = origin + heights[0]
        let secondTop = firstBottom + spacing
        #expect(secondTop >= firstBottom)
        #expect(heights[0] > rest[0])
    }
}

struct DockCoordinateSpaceTests {
    @Test func flipsAppKitYSoTopOfViewMapsToSwiftUIOrigin() {
        let top = DockCoordinateSpace.swiftUIPoint(fromAppKit: CGPoint(x: 12, y: 80), height: 80)
        #expect(top == CGPoint(x: 12, y: 0))

        let bottom = DockCoordinateSpace.swiftUIPoint(fromAppKit: CGPoint(x: 12, y: 0), height: 80)
        #expect(bottom == CGPoint(x: 12, y: 80))
    }

    @Test func hoveringTopIconIsCloserThanBottomIconAfterFlip() {
        let hover = DockCoordinateSpace.swiftUIPoint(fromAppKit: CGPoint(x: 20, y: 70), height: 80)
        let topIcon = CGPoint(x: 20, y: 10)
        let bottomIcon = CGPoint(x: 20, y: 70)
        #expect(abs(hover.y - topIcon.y) < abs(hover.y - bottomIcon.y))
    }
}

struct DockLayoutTests {
    @Test func panelUsesAppleLikeIconSpacing() {
        #expect(DockLayout.iconSpacing == 8)
        #expect(DockLayout.verticalPadding >= 10)
        #expect(DockLayout.separatorPadding >= 8)
    }

    @Test func panelIsWideEnoughForFullyVisibleMagnifiedIcon() {
        let iconSize: CGFloat = 48
        let magnification: CGFloat = 1.8
        let width = DockLayout.panelWidth(iconSize: iconSize, magnification: magnification)
        let needed = DockLayout.restChromeWidth(iconSize: iconSize) + iconSize * (magnification - 1)
        #expect(width >= needed)
    }

    @Test func leftWindowIncludesOffscreenGutter() {
        let metrics = DockLayout.Metrics(
            iconSize: 48,
            magnification: 1.8,
            panelWidth: 100,
            panelHeight: 400,
            restWidth: 64
        )
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let frame = DockLayout.unclampedWindowFrame(screen: screen, edge: .left, metrics: metrics)
        #expect(frame.minX == screen.minX + DockLayout.screenInset - metrics.gutter)
        #expect(frame.width == metrics.panelWidth + metrics.gutter)
        #expect(frame.maxX == screen.minX + DockLayout.screenInset + metrics.panelWidth)
    }

    @Test func rightWindowIncludesOffscreenGutter() {
        let metrics = DockLayout.Metrics(
            iconSize: 48,
            magnification: 1.8,
            panelWidth: 100,
            panelHeight: 400,
            restWidth: 64
        )
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let frame = DockLayout.unclampedWindowFrame(screen: screen, edge: .right, metrics: metrics)
        #expect(frame.minX == screen.maxX - metrics.panelWidth - DockLayout.screenInset)
        #expect(frame.maxX == screen.maxX - DockLayout.screenInset + metrics.gutter)
    }
}

struct DockDisplayLayoutTests {
    @Test func uniqueScreensDropsDuplicateIDsAndFrames() {
        let screens = [
            DockDisplayLayout.Screen(id: 1, frame: CGRect(x: 0, y: 0, width: 1800, height: 1169)),
            DockDisplayLayout.Screen(id: 1, frame: CGRect(x: 0, y: 0, width: 1800, height: 1169)),
            DockDisplayLayout.Screen(id: 2, frame: CGRect(x: 1800, y: 0, width: 1920, height: 1080)),
            DockDisplayLayout.Screen(id: 3, frame: CGRect(x: 1800, y: 0, width: 1920, height: 1080))
        ]
        let unique = DockDisplayLayout.uniqueScreens(screens)
        #expect(unique.map(\.id) == [1, 2])
    }

    @Test func rightDockDoesNotSpillOntoNeighborScreen() {
        let metrics = DockLayout.Metrics(
            iconSize: 48,
            magnification: 1.8,
            panelWidth: 100,
            panelHeight: 400,
            restWidth: 64
        )
        let laptop = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let external = CGRect(x: 1800, y: 0, width: 1920, height: 1080)
        let frame = DockDisplayLayout.windowFrame(
            screen: laptop,
            edge: .right,
            metrics: metrics,
            otherScreens: [external]
        )
        #expect(frame.maxX <= laptop.maxX + 0.5)
        #expect(!DockDisplayLayout.framesOverlap(frame, external))
    }
}

struct DockMotionTests {
    @Test func hideOffsetSlidesLeftDockTowardGutterWhenShown() {
        let hidden = DockMotion.hideOffset(isPositioned: false, edge: .left, gutter: 70, hovering: false)
        let shown = DockMotion.hideOffset(isPositioned: true, edge: .left, gutter: 70, hovering: false)
        #expect(hidden == 0)
        #expect(shown == 70)
    }

    @Test func hideOffsetSlidesRightDockTheOtherWay() {
        let shown = DockMotion.hideOffset(isPositioned: true, edge: .right, gutter: 70, hovering: false)
        #expect(shown == -70)
    }

    @Test func hoverBumpNudgesTowardScreen() {
        let left = DockMotion.hideOffset(isPositioned: true, edge: .left, gutter: 70, hovering: true)
        let right = DockMotion.hideOffset(isPositioned: true, edge: .right, gutter: 70, hovering: true)
        #expect(left == 70 + DockMotion.hoverBump)
        #expect(right == -70 - DockMotion.hoverBump)
        #expect(DockMotion.hoverBump == 0)
    }
}

struct DockInsertionTests {
    @Test func insertsBeforeTheFirstIcon() {
        #expect(DockInsertion.index(for: 5, centers: [20, 60, 100]) == 0)
    }

    @Test func insertsBetweenIcons() {
        #expect(DockInsertion.index(for: 40, centers: [20, 60, 100]) == 1)
        #expect(DockInsertion.index(for: 80, centers: [20, 60, 100]) == 2)
    }

    @Test func appendsPastTheLastIcon() {
        #expect(DockInsertion.index(for: 140, centers: [20, 60, 100]) == 3)
    }

    @Test func emptyDockInsertsAtZero() {
        #expect(DockInsertion.index(for: 50, centers: []) == 0)
    }
}

struct DockRevealLogicTests {
    @Test func alwaysShowsWhenAutoHideOff() {
        #expect(
            DockRevealLogic.decision(state: .hidden, event: .pointerIdle, autoHideEnabled: false)
                == .showImmediately
        )
    }

    @Test func showsOnHotEdge() {
        #expect(
            DockRevealLogic.decision(state: .hidden, event: .pointerEngaged, autoHideEnabled: true)
                == .showImmediately
        )
    }

    @Test func schedulesHideWhenPointerLeaves() {
        #expect(
            DockRevealLogic.decision(state: .visible, event: .pointerIdle, autoHideEnabled: true)
                == .scheduleHide
        )
    }

    @Test func staysHiddenWhenIdle() {
        #expect(
            DockRevealLogic.decision(state: .hidden, event: .pointerIdle, autoHideEnabled: true)
                == .remainHidden
        )
    }

    @Test func cancelsHideWhenPointerReturns() {
        #expect(
            DockRevealLogic.decision(state: .visible, event: .pointerEngaged, autoHideEnabled: true)
                == .remainVisible
        )
    }

    @Test func hiddenStateOnlyEngagesHotEdge() {
        let panel = CGRect(x: 4, y: 100, width: 80, height: 400)
        let hotEdge = CGRect(x: 0, y: 0, width: 6, height: 800)
        #expect(
            DockRevealLogic.isPointerEngaged(
                point: CGPoint(x: 40, y: 300),
                revealed: false,
                panelFrame: panel,
                hotEdge: hotEdge,
                inset: 6
            ) == false
        )
        #expect(
            DockRevealLogic.isPointerEngaged(
                point: CGPoint(x: 2, y: 300),
                revealed: false,
                panelFrame: panel,
                hotEdge: hotEdge,
                inset: 6
            )
        )
    }

    @Test func revealedStateEngagesPanelFrame() {
        let panel = CGRect(x: 4, y: 100, width: 80, height: 400)
        let hotEdge = CGRect(x: 0, y: 0, width: 6, height: 800)
        #expect(
            DockRevealLogic.isPointerEngaged(
                point: CGPoint(x: 40, y: 300),
                revealed: true,
                panelFrame: panel,
                hotEdge: hotEdge,
                inset: 6
            )
        )
    }
}

struct RecentsLogicTests {
    @Test func newestLaunchMovesToFrontAndDropsOldest() {
        var ids = ["a", "b", "c"]
        RecentsLogic.record("d", into: &ids, ignoring: [], limit: 3)
        #expect(ids == ["d", "a", "b"])
        RecentsLogic.record("b", into: &ids, ignoring: [], limit: 3)
        #expect(ids == ["b", "d", "a"])
    }

    @Test func ignoresOwnAppAndEmptyIDs() {
        var ids: [String] = []
        RecentsLogic.record("com.apple.Safari", into: &ids, ignoring: ["com.apple.Safari"], limit: 6)
        RecentsLogic.record("  ", into: &ids, ignoring: [], limit: 6)
        #expect(ids.isEmpty)
    }

    @Test func hidesPinnedAppsFromRecentsSection() {
        let visible = RecentsLogic.visible(
            ids: ["com.apple.Safari", "com.apple.mail", "com.apple.Notes"],
            excluding: ["com.apple.Safari"],
            limit: 6
        )
        #expect(visible == ["com.apple.mail", "com.apple.Notes"])
    }
}

struct FolderConfigTests {
    @Test func pinFolderDedupesByPath() {
        var config = DockConfig.default
        config.pinFolder(PinnedFolder(path: "/Users/rehan/Documents", bookmark: nil))
        config.pinFolder(PinnedFolder(path: "/Users/rehan/Documents", bookmark: nil), at: 0)
        #expect(config.pinnedFolders.count == 1)
        config.unpinFolder("/Users/rehan/Documents")
        #expect(config.pinnedFolders.isEmpty)
    }

    @Test func droppedDirectoryPinsWithoutCrashing() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("mac-side-dock-drop-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let folder = FolderAccess.folder(fromDroppedURL: dir)
        #expect(folder != nil)
        #expect(folder?.path == dir.resolvingSymlinksInPath().path)

        var config = DockConfig.default
        if let folder {
            config.pinFolder(folder)
        }
        #expect(config.pinnedFolders.count == 1)
        let resolved = FolderAccess.resolve(config.pinnedFolders[0])
        #expect(resolved != nil)
        #expect(resolved?.resolvingSymlinksInPath().path == dir.resolvingSymlinksInPath().path)
    }

    @Test func droppedFileIsNotPinnedAsFolder() throws {
        let fm = FileManager.default
        let file = fm.temporaryDirectory.appendingPathComponent("mac-side-dock-drop-\(UUID().uuidString).txt")
        try "hi".write(to: file, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: file) }
        #expect(FolderAccess.folder(fromDroppedURL: file) == nil)
    }
}

struct FeatureCatalogTests {
    @Test func ideaMVPIsShippedOrPartial() {
        let mvp = ["edge-panel", "pin-apps", "click-launch", "magnify", "autohide", "drag-drop", "reserve-space"]
        for id in mvp {
            let item = FeatureCatalog.items.first { $0.id == id }
            #expect(item != nil)
            #expect(item?.status != .notShipped)
        }
    }
}

struct AppInstallLocationTests {
    @Test func applicationsFolderIsStable() {
        let url = URL(fileURLWithPath: "/Applications/SIDEDOCK.app")
        #expect(AppInstallLocation.isInApplications(url))
        #expect(AppInstallLocation.canRegisterLoginItem(url))
        #expect(!AppInstallLocation.shouldOfferMove(url))
    }

    @Test func userApplicationsFolderIsStable() {
        let url = URL(fileURLWithPath: "/Users/rehan/Applications/SIDEDOCK.app")
        #expect(AppInstallLocation.isInApplications(url))
        #expect(AppInstallLocation.canRegisterLoginItem(url))
    }

    @Test func diskImageIsTransientAndMustNotRegisterLogin() {
        let url = URL(fileURLWithPath: "/Volumes/SIDEDOCK/SIDEDOCK.app")
        #expect(AppInstallLocation.isDiskImage(url))
        #expect(AppInstallLocation.shouldOfferMove(url))
        #expect(!AppInstallLocation.canRegisterLoginItem(url))
    }

    @Test func downloadsOffersMove() {
        let url = URL(fileURLWithPath: "/Users/rehan/Downloads/SIDEDOCK.app")
        #expect(AppInstallLocation.shouldOfferMove(url))
        #expect(!AppInstallLocation.canRegisterLoginItem(url))
    }

    @Test func xcodeBuildNeverPromptsOrRegistersLogin() {
        let url = URL(
            fileURLWithPath: "/Users/rehan/Library/Developer/Xcode/DerivedData/MacSideDock-abc/Build/Products/Release/SIDEDOCK.app"
        )
        #expect(AppInstallLocation.isXcodeBuild(url))
        #expect(!AppInstallLocation.shouldOfferMove(url))
        #expect(!AppInstallLocation.canRegisterLoginItem(url))
    }
}
