import SwiftUI

/// Logo visual usado en Moon Place: círculo con texto lunar.
struct MoonLogoView: View {
    let size: CGFloat
    let pulse: Bool

    @State private var opacity: Double = 0.0
    @State private var scale: Double = 0.9

    var body: some View {
        ZStack {
            // Ambient blue glow behind the logo
            Circle()
                .fill(MoonPlaceTheme.accent)
                .frame(width: size * 0.8, height: size * 0.8)
                .blur(radius: pulse ? size * 0.4 : size * 0.2)
                .opacity(pulse ? 0.6 : 0.3)
                .scaleEffect(pulse ? 1.1 : 1.0)
                .animation(
                    pulse ? Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )

            // The actual external logo
            Image("RX7BrandArtwork")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(scale)
                .scaleEffect(pulse ? 1.02 : 1.0)
                .opacity(opacity)
                .shadow(color: MoonPlaceTheme.accentBlue.opacity(0.8), radius: pulse ? 12 : 5)
                .animation(
                    pulse ? Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}

// swift-format-ignore
private extension Animation {
    static var slowEaseInOut: Animation {
        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
}




