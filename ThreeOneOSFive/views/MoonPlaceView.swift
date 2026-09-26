import SwiftUI

private enum MoonPlaceMode: String, CaseIterable, Identifiable {
    case v1f = "FREE FIRE"
    case v2fx = "FREE FIRE MAX"

    var id: String { rawValue }
}

private enum MoonPlaceCategory: String, CaseIterable, Identifiable {
    case aimbot = "AIMBOT"
    case holoArm = "HOLO ARM"
    case holoPJ = "HOLO PJ"
    case textura = "TEXTURA"
    case walkHack = "WALK HACK"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .aimbot: return "scope"
        case .holoArm: return "sparkles"
        case .holoPJ: return "person.fill"
        case .textura: return "paintpalette.fill"
        case .walkHack: return "figure.walk"
        }
    }
}

private struct MoonPlacePatchOption: Identifiable {
    let id: String
    let title: String
    let aliases: [String]
    let excludedAliases: [String]
    let category: MoonPlaceCategory
    let mode: MoonPlaceMode?

    var symbolName: String {
        switch id {
        case "holo-arm-rxt-1-vip": return "sparkles"
        case "holo-arm-basico-1-vip": return "square.grid.3x3.fill"
        default: return category.symbolName
        }
    }

    func matches(_ item: PatchLibraryItem) -> Bool {
        let names = [
            item.project?.name,
            item.packageURL.deletingPathExtension().lastPathComponent
        ].compactMap { $0 }
        return names.contains { name in
            aliases.contains { name.localizedCaseInsensitiveContains($0) }
                && !excludedAliases.contains { name.localizedCaseInsensitiveContains($0) }
        }
    }
}

private enum MoonPlaceCatalog {
    static let options: [MoonPlacePatchOption] = [
        .init(id: "v1f-aimdrag", title: "AIMDRAG", aliases: ["Avatar Aimdrag", "Aimdrag"], excludedAliases: [], category: .aimbot, mode: .v1f),
        .init(id: "v1f-aimbot-cabeza", title: "AIMBOT CABEZA", aliases: ["AIMBOT CABEZA"], excludedAliases: [], category: .aimbot, mode: .v1f),
        .init(id: "v1f-aimbot-cuello", title: "AIMBOT CUELLO", aliases: ["AIMBOT CUELLO", "CUELLO SIN ANTENA"], excludedAliases: [], category: .aimbot, mode: .v1f),
        .init(id: "v1f-aimbot-pecho", title: "AIMBOT PECHO", aliases: ["AIMBOT PECHO"], excludedAliases: [], category: .aimbot, mode: .v1f),
        .init(id: "v1f-balas-magica", title: "BALAS MÁGICA", aliases: ["BALAS MAGICAS"], excludedAliases: [], category: .aimbot, mode: .v1f),
        .init(id: "holo-arm-rxt-1-vip", title: "HOLO RXT 1 VIP", aliases: ["RTX FF NORMAL"], excludedAliases: [], category: .holoArm, mode: .v1f),
        .init(id: "holo-arm-basico-1-vip", title: "HOLO BASICO 1 VIP", aliases: ["ROBOTICO FF NORMAL", "BASICO FF NORMAL"], excludedAliases: [], category: .holoArm, mode: .v1f),
        .init(id: "holo-pj-amarillo-80", title: "PJ AMARILLO 80%", aliases: ["PJ FF NORMAL AMARILLO"], excludedAliases: [], category: .holoPJ, mode: .v1f),
        .init(id: "v2fx-aimdrag", title: "AIMDRAG", aliases: ["DRAG FF MAX SIN ANTENA"], excludedAliases: [], category: .aimbot, mode: .v2fx),
        .init(id: "v2fx-aimbot-cabeza", title: "AIMBOT CABEZA", aliases: ["CABEZA FF MAX SIN ANTENA"], excludedAliases: [], category: .aimbot, mode: .v2fx),
        .init(id: "v2fx-aimbot-cuello", title: "AIMBOT CUELLO", aliases: ["CUELLO SIN ANTENA FF MAX"], excludedAliases: [], category: .aimbot, mode: .v2fx),
        .init(id: "v2fx-aimbot-pecho", title: "AIMBOT PECHO", aliases: ["AIMBOT MOON PECHO"], excludedAliases: [], category: .aimbot, mode: .v2fx),
        .init(id: "v2fx-balas-magica", title: "BALAS MÁGICA", aliases: ["BALA MAGICA FF MAX"], excludedAliases: [], category: .aimbot, mode: .v2fx),
        .init(id: "v2fx-holo-arm-rxt-1-vip", title: "HOLO RXT 1 VIP", aliases: ["RTX FF MAX"], excludedAliases: [], category: .holoArm, mode: .v2fx),
        .init(id: "v2fx-holo-arm-basico-1-vip", title: "HOLO BASICO 1 VIP", aliases: ["ROBOTICO FF MAX", "BASICO FF MAX"], excludedAliases: [], category: .holoArm, mode: .v2fx),
        .init(id: "v2fx-holo-pj-amarillo-80", title: "PJ AMARILLO 80%", aliases: ["PJ FF MAX"], excludedAliases: [], category: .holoPJ, mode: .v2fx)
    ]
}

struct MoonPlaceView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @AppStorage(MoonPlaceTheme.backgroundPaletteStorageKey)
    private var backgroundPaletteID = MoonPlaceBackgroundPalette.violet.rawValue
    @AppStorage(MoonPlaceTheme.interfacePaletteStorageKey)
    private var interfacePaletteID = MoonPlaceInterfacePalette.violet.rawValue
    @State private var selectedMode: MoonPlaceMode?
    
    @State private var selectedOption: MoonPlacePatchOption?
    @State private var workingOptionID: String?
    @State private var message: String?
    @State private var showAppearance = false

    var body: some View {
        ZStack {
            MoonPlaceBackground()
            if selectedMode == nil {
                MoonPlaceModeView(selectedMode: $selectedMode)
                    .transition(.opacity)
            } else {
                MoonPlaceSelectorView(
                    mode: selectedMode!,
                    options: MoonPlaceCatalog.options.filter { $0.mode == nil || $0.mode == selectedMode! },
                    items: patchStore.items,
                    isBusy: patchStore.isBusy,
                    workingOptionID: workingOptionID,
                    onBack: { selectedMode = nil },
                    onAppearance: { showAppearance = true },
                    onToggle: toggle
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: selectedMode)
        .animation(.easeInOut(duration: 0.24), value: backgroundPaletteID)
        .animation(.easeInOut(duration: 0.24), value: interfacePaletteID)
        .sheet(item: $selectedOption) { option in
            MoonPlacePatchInfoView(option: option, item: matchingItem(for: option))
        }
        .sheet(isPresented: $showAppearance) {
            MoonPlaceAppearanceView()
        }
        .alert("RX7 MODZ", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func matchingItem(for option: MoonPlacePatchOption) -> PatchLibraryItem? {
        patchStore.items.first(where: option.matches)
    }

    private func toggle(_ option: MoonPlacePatchOption) {
        guard let item = matchingItem(for: option), let project = item.project else {
            message = "Importa el paquete .3105 correspondiente en Parches avanzados para usar esta opción."
            return
        }
        guard workingOptionID == nil else { return }
        workingOptionID = option.id
        Task.detached(priority: .userInitiated) {
            do {
                if let receipt = DevicePatchService.latestReceipt(projectID: project.id) {
                    try DevicePatchService.restore(receipt: receipt)
                } else {
                    let source = item.summary.schemaVersion >= 2 && item.canInspectContents
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : project
                    _ = try DevicePatchService.apply(project: source)
                }
                await MainActor.run {
                    patchStore.reload()
                    workingOptionID = nil
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    workingOptionID = nil
                    message = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    workingOptionID = nil
                    message = "The patch operation failed. Check device support and the target app."
                }
            }
        }
    }
}

private struct MoonPlaceBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var galaxyDrift = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MoonPlaceTheme.background

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MoonPlaceTheme.accent.opacity(0.52), MoonPlaceTheme.accent.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: geometry.size.width * 0.68
                        )
                    )
                    .frame(width: geometry.size.width * 1.38, height: geometry.size.width * 1.38)
                    .offset(
                        x: galaxyDrift ? -geometry.size.width * 0.38 : geometry.size.width * 0.22,
                        y: galaxyDrift ? -geometry.size.height * 0.27 : -geometry.size.height * 0.08
                    )
                    .blur(radius: 22)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 11).repeatForever(autoreverses: true),
                        value: galaxyDrift
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MoonPlaceTheme.accentBlue.opacity(0.25), MoonPlaceTheme.accent.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: geometry.size.width * 0.52
                        )
                    )
                    .frame(width: geometry.size.width * 1.05, height: geometry.size.width * 1.05)
                    .offset(
                        x: galaxyDrift ? geometry.size.width * 0.34 : -geometry.size.width * 0.30,
                        y: galaxyDrift ? geometry.size.height * 0.24 : geometry.size.height * 0.38
                    )
                    .blur(radius: 30)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 14).repeatForever(autoreverses: true),
                        value: galaxyDrift
                    )

                if !reduceMotion {
                    MoonPlaceParticleField()
                        .opacity(0.9)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            galaxyDrift = true
        }
    }
}

private struct MoonPlaceModeView: View {
    @Binding var selectedMode: MoonPlaceMode?

    var body: some View {
        VStack(spacing: 16) {
            MoonPlaceHeader(title: "Selecciona tu perfil", subtitle: "Perfiles de control disponibles")
            
            VStack(spacing: 12) {
                ForEach(MoonPlaceMode.allCases) { mode in
                    Button { 
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        selectedMode = mode 
                    } label: {
                        HStack {
                            ZStack {
                                Circle().fill(MoonPlaceTheme.accentBlue.opacity(0.2)).frame(width: 36, height: 36)
                                Image(systemName: mode == .v1f ? "scope" : "bolt.horizontal.fill")
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode == .v1f ? "FREE FIRE TH" : mode.rawValue)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                                Text("Perfil de control")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("ENTRAR")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                            }
                        }
                        .padding(16)
                        .background(MoonPlaceTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(MoonPlaceTheme.accentBlue.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 500)
    }
}

private struct MoonPlaceSelectorView: View {
    let mode: MoonPlaceMode
    let options: [MoonPlacePatchOption]
    let items: [PatchLibraryItem]
    let isBusy: Bool
    let workingOptionID: String?
    let onBack: () -> Void
    let onAppearance: () -> Void
    let onToggle: (MoonPlacePatchOption) -> Void

    @State private var selectedCategory: MoonPlaceCategory = .aimbot

    private var visibleOptions: [MoonPlacePatchOption] {
        options.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Button(action: onBack) { 
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(MoonPlaceTheme.surface, in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        AppLogo(size: 32)
                        Text("RX7 MODZ")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(2)
                    }
                    Spacer()
                    Button(action: onAppearance) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(MoonPlaceTheme.surface, in: Circle())
                    }
                }
                .foregroundStyle(.white)
                
                VStack(spacing: 6) {
                    Text("Panel de control")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack {
                        Circle().fill(MoonPlaceTheme.accentBlue).frame(width: 6, height: 6).moonGlow(MoonPlaceTheme.accentBlue, radius: 4)
                        Text(mode == .v1f ? "FREE FIRE TH" : mode.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                    }
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(MoonPlaceTheme.success)
                        .frame(width: 7, height: 7)
                    Text("Sistema en línea")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                    Spacer()
                    if isBusy {
                        ProgressView()
                            .tint(MoonPlaceTheme.accentBlue)
                            .scaleEffect(0.8)
                    }
                }
                
                categoryTabs
                optionList
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(MoonPlaceCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .foregroundStyle(selectedCategory == category ? .white : .white.opacity(0.68))
                            .background(
                                selectedCategory == category ? MoonPlaceTheme.accentBlue : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(MoonPlaceTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(MoonPlaceTheme.border, lineWidth: 1))
        .accessibilityLabel("Categorías de opciones")
    }

    @ViewBuilder
    private var optionList: some View {
        if visibleOptions.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: selectedCategory.symbolName)
                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                Text("Aún no hay opciones disponibles en esta categoría.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(MoonPlaceTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MoonPlaceTheme.border, lineWidth: 1))
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleOptions) { option in
                    optionRow(option)
                }
            }
        }
    }

    private func optionRow(_ option: MoonPlacePatchOption) -> some View {
        let item = items.first(where: option.matches)
        let isApplied = item.map { DevicePatchService.latestReceipt(projectID: $0.id) != nil } ?? false
        let isWorking = workingOptionID == option.id

        return Button {
            let impact = UIImpactFeedbackGenerator(style: isApplied ? .soft : .medium)
            impact.impactOccurred()
            onToggle(option)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isWorking ? "arrow.triangle.2.circlepath" : option.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                    .frame(width: 22)

                Text(option.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                ZStack(alignment: isApplied ? .trailing : .leading) {
                    Capsule()
                        .fill(isApplied ? MoonPlaceTheme.accentBlue : Color.white.opacity(0.1))
                        .frame(width: 46, height: 26)
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                isApplied ? MoonPlaceTheme.accentBlue.opacity(0.12) : MoonPlaceTheme.surface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isApplied ? MoonPlaceTheme.accentBlue : MoonPlaceTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy || workingOptionID != nil)
        .accessibilityLabel(option.title)
        .accessibilityValue(isApplied ? "Activado" : "Desactivado")
        .accessibilityHint("Toca para activar o desactivar")
    }
}

private struct MoonPlacePatchInfoView: View {
    let option: MoonPlacePatchOption
    let item: PatchLibraryItem?

    var body: some View {
        VStack(spacing: 18) {
            AppLogo(size: 64)
            Text(option.title).font(.title2.bold())
            Text(item?.packageURL.lastPathComponent ?? "Paquete no cargado")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Usa el botón para aplicar el patch o restaurar los archivos originales.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}

private struct MoonPlacePaletteOption: Identifiable {
    let id: String
    let title: String
    let color: Color
}

private struct MoonPlaceAppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MoonPlaceTheme.backgroundPaletteStorageKey)
    private var backgroundPaletteID = MoonPlaceBackgroundPalette.violet.rawValue
    @AppStorage(MoonPlaceTheme.interfacePaletteStorageKey)
    private var interfacePaletteID = MoonPlaceInterfacePalette.violet.rawValue

    private var backgroundOptions: [MoonPlacePaletteOption] {
        MoonPlaceBackgroundPalette.allCases.map {
            MoonPlacePaletteOption(id: $0.rawValue, title: $0.title, color: $0.background)
        }
    }

    private var interfaceOptions: [MoonPlacePaletteOption] {
        MoonPlaceInterfacePalette.allCases.map {
            MoonPlacePaletteOption(id: $0.rawValue, title: $0.title, color: $0.primary)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Personaliza los colores")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                        Text("Cambia el fondo y los botones, iconos y bordes de la interfaz.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    paletteSection(
                        title: "FONDO",
                        description: "Elige el tono oscuro del panel.",
                        options: backgroundOptions,
                        selection: $backgroundPaletteID
                    )

                    paletteSection(
                        title: "INTERFAZ",
                        description: "Elige el color de botones, iconos y detalles.",
                        options: interfaceOptions,
                        selection: $interfacePaletteID
                    )

                    Button {
                        backgroundPaletteID = MoonPlaceBackgroundPalette.violet.rawValue
                        interfacePaletteID = MoonPlaceInterfacePalette.violet.rawValue
                    } label: {
                        Label("RESTAURAR COLORES VIOLETA", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                            .background(MoonPlaceTheme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(22)
            }
            .background(MoonPlaceTheme.background.ignoresSafeArea())
            .navigationTitle("Apariencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(MoonPlaceTheme.accentBlue)
        .presentationDetents([.medium, .large])
    }

    private func paletteSection(
        title: String,
        description: String,
        options: [MoonPlacePaletteOption],
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(MoonPlaceTheme.accentBlue)
            Text(description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options) { option in
                    let isSelected = selection.wrappedValue == option.id
                    Button {
                        selection.wrappedValue = option.id
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(option.color)
                                .frame(height: 38)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.black))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.6), radius: 3)
                                    }
                                }

                            Text(option.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(MoonPlaceTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? MoonPlaceTheme.accentBlue : MoonPlaceTheme.border,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title): \(option.title)")
                    .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

private struct MoonPlaceHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            AppLogo(size: 70)
            Text(title).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.white.opacity(0.65))
        }
    }
}

