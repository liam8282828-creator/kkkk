import SwiftUI
import UIKit

struct RX7KeyLoginView: View {
    let onAuthenticated: () -> Void

    @State private var licenseKey = ""
    @State private var errorMessage: String?
    @State private var isValidating = false
    @FocusState private var keyFieldFocused: Bool

    private let authenticationClient = SupabaseAuthenticationClient()

    var body: some View {
        ZStack {
            MoonPlaceTheme.background.ignoresSafeArea()
            MoonPlaceParticleField()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 56)

                    ZStack {
                        Circle()
                            .fill(MoonPlaceTheme.accentBlue.opacity(0.14))
                            .frame(width: 92, height: 92)
                            .moonGlow(MoonPlaceTheme.accentBlue, radius: 12)
                        Image(systemName: "key.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                    }

                    VStack(spacing: 8) {
                        Text("RX7 MODZ SYSTEM")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .kerning(1.2)
                            .foregroundStyle(MoonPlaceTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Pega tu key para ingresar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MoonPlaceTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("KEY DE ACCESO")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MoonPlaceTheme.textSecondary)

                        HStack(spacing: 10) {
                            Image(systemName: "key.horizontal")
                                .foregroundStyle(MoonPlaceTheme.accentBlue)

                            TextField("Pega tu key aquí", text: $licenseKey)
                                .font(.system(.body, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.go)
                                .focused($keyFieldFocused)
                                .onSubmit { Task { await validateKey() } }
                                .accessibilityLabel("Key de acceso")

                            Button("PEGAR") {
                                if let pasted = UIPasteboard.general.string {
                                    licenseKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                            .accessibilityLabel("Pegar key del portapapeles")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(MoonPlaceTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(MoonPlaceTheme.border, lineWidth: 1)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(MoonPlaceTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    .frame(maxWidth: 390)

                    Button {
                        Task { await validateKey() }
                    } label: {
                        HStack(spacing: 10) {
                            if isValidating {
                                ProgressView()
                                    .tint(.white)
                                Text("VALIDANDO…")
                            } else {
                                Text("INGRESAR")
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .font(.subheadline.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(MoonPlaceTheme.buttonGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isValidating || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(isValidating || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1)
                    .frame(maxWidth: 390)

                    Text("RX7 MODZ · ACCESO AUTORIZADO")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(MoonPlaceTheme.textSecondary.opacity(0.7))
                        .padding(.top, 4)

                    Spacer(minLength: 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @MainActor
    private func validateKey() async {
        let cleanedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty, !isValidating else { return }

        isValidating = true
        errorMessage = nil
        defer { isValidating = false }

        do {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_DEVICE"
            _ = try await authenticationClient.validateLicenseKey(key: cleanedKey, deviceID: deviceID)
            licenseKey = ""
            keyFieldFocused = false
            onAuthenticated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var licenseAuthorized = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if licenseAuthorized {
                mainAppContent
                    .transition(.opacity)
            } else {
                RX7KeyLoginView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        licenseAuthorized = true
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var mainAppContent: some View {
        ZStack {
            MoonPlaceView()
                .tint(AppTheme.accent)
                .imageScale(.small)
                .onChange(of: patchDraftCoordinator.request?.id) { requestID in
                    if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
                }
                .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
                    if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
                }
                .onChange(of: developerModeEnabled) { _ in
                    tabNavigation.reconcileSelection(with: featureVisibility)
                }
                .onAppear {
                    tabNavigation.reconcileSelection(with: featureVisibility)
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showLogs) { LogView() }
                .patchStorePresentation(patchStore)
                .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
        }
    }

    private var obsoleteBody: some View {
        EmptyView()
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}

