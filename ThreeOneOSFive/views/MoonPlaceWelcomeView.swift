import SwiftUI

/// Animated welcome splash: logo + "WELCOME BACK TO MOON PLACE".
/// Plays once and calls `onFinish`; the caller animates it away.
struct MoonPlaceWelcomeView: View {
    var onFinish: () -> Void

    @State private var appear = false
    @State private var glowPulse = false

    private let holdDuration: TimeInterval = 2.4

        var body: some View {
        ZStack {
            MoonPlaceTheme.background.ignoresSafeArea()
            MoonPlaceParticleField()

            VStack(spacing: 20) {
                MoonLogoView(size: 112, pulse: glowPulse)
                    .scaleEffect(appear ? 1.0 : 0.55)
                    .opacity(appear ? 1.0 : 0.0)

                VStack(spacing: 6) {
                    Text("WELCOME BACK")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(MoonPlaceTheme.textPrimary)
                        .kerning(1.5)

                    Text("TO MOON PLACE")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MoonPlaceTheme.textSecondary)
                        .kerning(4)
                }
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 18)
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale(scale: 1.06)))
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                onFinish()
            }
        }
    }
}

