import SwiftUI

struct RX7SplashView: View {
    @Binding var showSplash: Bool
    @State private var dismissalScheduled = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("RX7BrandArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 32)
                    .overlay(Color.black.opacity(0.62))

                VStack(spacing: 18) {
                    Spacer(minLength: 0)

                    Image("RX7BrandArtwork")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geometry.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
                        .padding(.horizontal, 12)

                    ProgressView()
                        .tint(.white)

                    Text("INITIALIZING RX7 MODZ")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .tracking(2)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 36)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !dismissalScheduled else { return }
            dismissalScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    showSplash = false
                }
            }
        }
    }
}