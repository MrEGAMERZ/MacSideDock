import AppKit
import SwiftUI

struct PreferencesView: View {
    var store: DockConfigStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginItemError: String?
    @State private var selectedTab: SettingsTab = .dock

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case dock
        case general
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dock: return "Dock"
            case .general: return "General"
            case .about: return "About"
            }
        }

        var systemImage: String {
            switch self {
            case .dock: return "dock.rectangle"
            case .general: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Group {
                switch selectedTab {
                case .dock:
                    dockTab
                case .general:
                    generalTab
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 520, height: 600)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private var dockTab: some View {
        Form {
            Section {
                HStack {
                    Spacer(minLength: 0)
                    Image("DockPreview")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                    Spacer(minLength: 0)
                }
                .listRowBackground(Color.clear)
            } header: {
                Text(AppBrand.name)
            } footer: {
                Text("Pinned apps: \(store.config.pinnedApps.count) of \(DockConfig.maximumPinnedApps). Keep at least \(DockConfig.minimumPinnedApps).")
            }

            Section {
                sizeSlider
                magnificationSlider
            } header: {
                Text("Size")
            } footer: {
                Text("Hovering an icon enlarges it and pushes neighbors apart, like the system Dock.")
            }

            Section {
                Picker("Position on screen", selection: edgeBinding) {
                    ForEach(DockEdge.allCases) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }

                Toggle("Automatically hide and show the Dock", isOn: autoHideBinding)
                    .disabled(store.config.reserveScreenSpace)

                Toggle("Keep dock visible", isOn: reserveBinding)

                Toggle("Show indicators for open applications", isOn: indicatorsBinding)
            } header: {
                Text("Dock")
            } footer: {
                Text("Keeping the dock visible does not resize other windows. macOS only reserves space for the system Dock.")
            }

            Section {
                Toggle("Show recent applications", isOn: recentsBinding)
                if store.config.showRecents {
                    Stepper(
                        value: recentsLimitBinding,
                        in: Int(DockConfig.minimumRecentsLimit)...Int(DockConfig.maximumRecentsLimit)
                    ) {
                        Text("\(store.config.recentsLimit) recent apps")
                    }
                }
            } header: {
                Text("Recent Applications")
            } footer: {
                Text("Drop a folder onto the dock, then hold the pointer over it to look inside. Right-click the dock for hiding, magnification, and position.")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    private var sizeSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Size")
            Slider(value: iconSizeBinding, in: DockConfig.minimumIconSize...DockConfig.maximumIconSize, step: 4)
            HStack {
                Text("Small")
                Spacer()
                Text("Large")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var magnificationSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Magnification")
            Slider(
                value: magnificationBinding,
                in: DockConfig.minimumMagnification...DockConfig.maximumMagnification,
                step: 0.1
            )
            HStack {
                Text("Off")
                Spacer()
                Text("Large")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var generalTab: some View {
        Form {
            Section("Login") {
                Toggle("Open at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .foregroundStyle(.red)
                }
            }

            Section("Advanced") {
                LabeledContent("Configuration") {
                    Text(store.fileURL.lastPathComponent)
                        .foregroundStyle(.secondary)
                }
                Button("Show in Finder") {
                    store.persist()
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
                Button("Revert to Defaults", role: .destructive) {
                    store.replace(.default)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    private var edgeBinding: Binding<DockEdge> {
        Binding(
            get: { store.config.edge },
            set: { newValue in store.update { $0.edge = newValue } }
        )
    }

    private var autoHideBinding: Binding<Bool> {
        Binding(
            get: { store.config.autoHide },
            set: { newValue in store.update { $0.autoHide = newValue } }
        )
    }

    private var reserveBinding: Binding<Bool> {
        Binding(
            get: { store.config.reserveScreenSpace },
            set: { newValue in store.update { $0.reserveScreenSpace = newValue } }
        )
    }

    private var iconSizeBinding: Binding<Double> {
        Binding(
            get: { store.config.iconSize },
            set: { newValue in store.update { $0.iconSize = newValue } }
        )
    }

    private var magnificationBinding: Binding<Double> {
        Binding(
            get: { store.config.magnification },
            set: { newValue in store.update { $0.setMagnification(newValue) } }
        )
    }

    private var recentsBinding: Binding<Bool> {
        Binding(
            get: { store.config.showRecents },
            set: { newValue in store.update { $0.showRecents = newValue } }
        )
    }

    private var recentsLimitBinding: Binding<Int> {
        Binding(
            get: { store.config.recentsLimit },
            set: { newValue in store.update { $0.recentsLimit = newValue } }
        )
    }

    private var indicatorsBinding: Binding<Bool> {
        Binding(
            get: { store.config.showRunningIndicators },
            set: { newValue in store.update { $0.showRunningIndicators = newValue } }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var brandIcon: NSImage {
        if let named = NSImage(named: "AppIconImage") {
            return named
        }
        if let appIcon = NSImage(named: NSImage.applicationIconName), appIcon.size.width > 32 {
            return appIcon
        }
        return NSApp.applicationIconImage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(nsImage: brandIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 4)

                Text(AppBrand.name)
                    .font(.title.weight(.semibold))

                Text("Version \(version)")
                    .foregroundStyle(.secondary)

                Text("A secondary Dock for the side of your screen. Pin apps, browse recent items, and peek into folders — without Accessibility or Screen Recording permission.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                Image("DockPreview")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                    .padding(.top, 8)

                Text("Your side dock, cropped from a live screenshot.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }
}
