import Foundation

/// Pure path rules for install location. AppKit stays in `AppInstall`.
nonisolated enum AppInstallLocation: Sendable {
    static func isInApplications(_ url: URL) -> Bool {
        url.standardizedFileURL.deletingLastPathComponent().lastPathComponent == "Applications"
    }

    static func isXcodeBuild(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.contains("/DerivedData/") || path.contains("/Build/Products/")
    }

    static func isDiskImage(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.hasPrefix("/Volumes/") && !isInApplications(url)
    }

    static func isTransient(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        if isDiskImage(url) { return true }
        return path.contains("/Downloads/")
            || path.contains("/Desktop/")
            || path.contains("/tmp/")
            || path.contains("/Temp/")
    }

    /// Offer “Move to Applications” from a DMG, Downloads, or Desktop — never from Xcode.
    static func shouldOfferMove(_ url: URL) -> Bool {
        !isXcodeBuild(url) && !isInApplications(url) && isTransient(url)
    }

    /// Login items must point at a copy that survives ejecting the installer.
    static func canRegisterLoginItem(_ url: URL) -> Bool {
        isInApplications(url) && !isXcodeBuild(url)
    }
}
