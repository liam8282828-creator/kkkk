import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false

    @State private var enableAnimations = true
    @State private var enableParticles = true
    @State private var enableHaptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo(size: 60)
                            .moonGlow(MoonPlaceTheme.accent, radius: 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("RX7 MODZ").font(.system(size: 22, weight: .black, design: .rounded))
                                .tracking(2)
                            Text("Version \(appVersion)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MoonPlaceTheme.accentBlue)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(MoonPlaceTheme.surface)
                }

                Section {
                    LabeledContent("USERNAME", value: "ADMIN")
                    LabeledContent("MEMBERSHIP", value: "RX7 MODZ PREMIER")
                    LabeledContent("ACCESS STATUS", value: "ACTIVE")
                        .foregroundStyle(MoonPlaceTheme.success)
                } header: {
                    Text("ACCOUNT").font(.caption.weight(.bold))
                }
                .listRowBackground(MoonPlaceTheme.surface)

                Section {
                    Toggle("Animations", isOn: $enableAnimations)
                    Toggle("Particle Effects", isOn: $enableParticles)
                    Toggle("Haptic Feedback", isOn: $enableHaptics)
                } header: {
                    Text("INTERFACE SETTINGS").font(.caption.weight(.bold))
                }
                .listRowBackground(MoonPlaceTheme.surface)
                
                Section {
                    Toggle(isOn: $cleanerEnabled) {
                        Label("System Cleaner", systemImage: "sparkles")
                    }
                    Toggle(isOn: $developerModeEnabled) {
                        Label("Developer Mode", systemImage: "hammer.fill")
                    }
                } header: {
                    Text("FEATURES").font(.caption.weight(.bold))
                } footer: {
                    Text("Enable developer mode to access advanced patches.")
                }
                .listRowBackground(MoonPlaceTheme.surface)

                Section {
                    LabeledContent("HARDWARE", value: AppInfo.displayMachineName)
                    LabeledContent("SYSTEM OS", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                } header: {
                    Text("DEVICE INFO").font(.caption.weight(.bold))
                }
                .listRowBackground(MoonPlaceTheme.surface)

                Section {
                    creditsRow(
                        name: "ENYELL DEV",
                        role: "Developer & System Designer",
                        url: "https://github.com"
                    )
                } header: {
                    Text("DEVELOPER").font(.caption.weight(.bold))
                }
                .listRowBackground(MoonPlaceTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(MoonPlaceTheme.background)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(MoonPlaceTheme.accentBlue)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    @ViewBuilder
    private func creditsRow(name: String, role: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                        Text(role)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.title2)
                        .foregroundStyle(MoonPlaceTheme.accentBlue)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
