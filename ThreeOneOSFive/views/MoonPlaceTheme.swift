import SwiftUI

enum MoonPlaceBackgroundPalette: String, CaseIterable, Identifiable {
    case violet
    case midnight
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .violet: return "Violeta"
        case .midnight: return "Azul noche"
        case .graphite: return "Grafito"
        }
    }

    var background: Color {
        switch self {
        case .violet: return Color(red: 0.02, green: 0.008, blue: 0.04)
        case .midnight: return Color(red: 0.008, green: 0.015, blue: 0.045)
        case .graphite: return Color(red: 0.018, green: 0.022, blue: 0.03)
        }
    }

    var surface: Color {
        switch self {
        case .violet: return Color(red: 0.065, green: 0.04, blue: 0.10)
        case .midnight: return Color(red: 0.025, green: 0.045, blue: 0.105)
        case .graphite: return Color(red: 0.06, green: 0.07, blue: 0.095)
        }
    }

    var glow: Color {
        switch self {
        case .violet: return Color(red: 0.12, green: 0.04, blue: 0.21)
        case .midnight: return Color(red: 0.04, green: 0.08, blue: 0.22)
        case .graphite: return Color(red: 0.09, green: 0.10, blue: 0.14)
        }
    }
}

enum MoonPlaceInterfacePalette: String, CaseIterable, Identifiable {
    case violet
    case cyan
    case rose
    case emerald
    case gold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .violet: return "Violeta"
        case .cyan: return "Cian"
        case .rose: return "Rosa"
        case .emerald: return "Verde"
        case .gold: return "Dorado"
        }
    }

    var primary: Color {
        switch self {
        case .violet: return Color(red: 0.62, green: 0.34, blue: 1.00)
        case .cyan: return Color(red: 0.28, green: 0.82, blue: 1.00)
        case .rose: return Color(red: 0.98, green: 0.37, blue: 0.63)
        case .emerald: return Color(red: 0.30, green: 0.92, blue: 0.65)
        case .gold: return Color(red: 0.98, green: 0.72, blue: 0.28)
        }
    }

    var deep: Color {
        switch self {
        case .violet: return Color(red: 0.30, green: 0.10, blue: 0.56)
        case .cyan: return Color(red: 0.06, green: 0.30, blue: 0.47)
        case .rose: return Color(red: 0.48, green: 0.08, blue: 0.24)
        case .emerald: return Color(red: 0.04, green: 0.38, blue: 0.24)
        case .gold: return Color(red: 0.42, green: 0.24, blue: 0.04)
        }
    }

    var border: Color {
        switch self {
        case .violet: return Color(red: 0.34, green: 0.18, blue: 0.55)
        case .cyan: return Color(red: 0.08, green: 0.44, blue: 0.60)
        case .rose: return Color(red: 0.55, green: 0.12, blue: 0.32)
        case .emerald: return Color(red: 0.12, green: 0.52, blue: 0.36)
        case .gold: return Color(red: 0.56, green: 0.37, blue: 0.08)
        }
    }
}

// MARK: - Moon Place Theme
/// Central design system for the Moon Place interface.
enum MoonPlaceTheme {
    static let backgroundPaletteStorageKey = "moonplace.backgroundPalette"
    static let interfacePaletteStorageKey = "moonplace.interfacePalette"

    private static var selectedBackground: MoonPlaceBackgroundPalette {
        let rawValue = UserDefaults.standard.string(forKey: backgroundPaletteStorageKey) ?? MoonPlaceBackgroundPalette.violet.rawValue
        return MoonPlaceBackgroundPalette(rawValue: rawValue) ?? .violet
    }

    private static var selectedInterface: MoonPlaceInterfacePalette {
        let rawValue = UserDefaults.standard.string(forKey: interfacePaletteStorageKey) ?? MoonPlaceInterfacePalette.violet.rawValue
        return MoonPlaceInterfacePalette(rawValue: rawValue) ?? .violet
    }

    // MARK: Core palette
    static var background: Color { selectedBackground.background }
    static var surface: Color { selectedBackground.surface }
    static let surfaceHighlight = Color.white.opacity(0.06)
    static var border: Color { selectedInterface.border.opacity(0.48) }

    static var accent: Color { selectedInterface.deep }
    static var accentBlue: Color { selectedInterface.primary }
    static let danger = Color(red: 0.95, green: 0.20, blue: 0.20)
    static let success = Color(red: 0.20, green: 0.90, blue: 0.40)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.60)

    // MARK: Gradients
    static var heroGradient: LinearGradient {
        LinearGradient(
        colors: [accent, accentBlue, Color(red: 0.83, green: 0.27, blue: 0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
        )
    }

    static var buttonGradient: LinearGradient {
        LinearGradient(
        colors: [accent, accentBlue],
        startPoint: .leading,
        endPoint: .trailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [selectedBackground.glow, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Metrics
    static let cornerRadius: CGFloat = 18
}

// MARK: - Glow
private struct MoonPlaceGlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.55), radius: radius)
            .shadow(color: color.opacity(0.25), radius: radius * 2)
    }
}

extension View {
    /// Soft neon glow used across the Moon Place interface.
    func moonGlow(_ color: Color = MoonPlaceTheme.accent, radius: CGFloat = 10) -> some View {
        modifier(MoonPlaceGlowModifier(color: color, radius: radius))
    }
}

// MARK: - Card container
private struct MoonPlaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MoonPlaceTheme.cornerRadius, style: .continuous)
                    .fill(MoonPlaceTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: MoonPlaceTheme.cornerRadius, style: .continuous)
                            .strokeBorder(MoonPlaceTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
            )
    }
}

extension View {
    /// Premium dark card look for panels and rows.
    func moonCard() -> some View {
        modifier(MoonPlaceCardModifier())
    }
}

// MARK: - Particle field
private struct MoonPlaceParticle: Identifiable {
    let id = UUID()
    let x: Double          // 0...1 relative width
    let yOffset: Double    // extra travel above the top edge
    let radius: Double
    let speed: Double
    let phase: Double
    let colorIndex: Int
}

/// Lightweight animated particle field (~22 Canvas particles, 30 fps cap, GPU friendly).
struct MoonPlaceParticleField: View {
    @State private var particles: [MoonPlaceParticle] = []

    private static var palette: [Color] {
        [
            MoonPlaceTheme.accent,
            MoonPlaceTheme.accentBlue,
            MoonPlaceTheme.accentBlue.opacity(0.72)
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let drift = now * particle.speed + particle.phase
                    let fraction = drift.truncatingRemainder(dividingBy: 1.0)
                    let y = size.height - fraction * (size.height + particle.yOffset)
                    let wobble = sin(now * 1.4 + particle.phase) * 8
                    let x = particle.x * size.width + wobble
                    let rect = CGRect(
                        x: x,
                        y: y,
                        width: particle.radius * 2,
                        height: particle.radius * 2
                    )
                    let color = Self.palette[particle.colorIndex % Self.palette.count]
                    context.opacity = 0.10 + 0.18 * fraction
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: seed)
    }

    private func seed() {
        guard particles.isEmpty else { return }
        var generator = SystemRandomNumberGenerator()
        particles = (0..<22).map { _ in
            MoonPlaceParticle(
                x: Double.random(in: 0...1, using: &generator),
                yOffset: Double.random(in: 40...140, using: &generator),
                radius: Double.random(in: 1.2...2.8, using: &generator),
                speed: Double.random(in: 0.04...0.12, using: &generator),
                phase: Double.random(in: 0...(2 * .pi), using: &generator),
                colorIndex: Int.random(in: 0..<3, using: &generator)
            )
        }
    }
}

