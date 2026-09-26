import SwiftUI

/// Wrapper público del campo de partículas de Moon Place.
/// `count` controla el número de partículas (rendimiento GPU-friendly).
struct MoonParticleField: View {
    let count: Int

    @State private var particles: [MoonParticle] = []

    private static let palette: [Color] = [
        MoonPlaceTheme.accent,
        MoonPlaceTheme.accentBlue,
        MoonPlaceTheme.danger
    ]

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
                        x: x, y: y,
                        width: particle.radius * 2, height: particle.radius * 2
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
        particles = (0..<count).map { _ in
            MoonParticle(
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

// swift-format-ignore
private struct MoonParticle: Identifiable {
    let id = UUID()
    let x: Double
    let yOffset: Double
    let radius: Double
    let speed: Double
    let phase: Double
    let colorIndex: Int
}
