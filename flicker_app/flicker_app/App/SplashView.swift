import SwiftUI

/// Brief branded splash shown on cold launch, before RootView decides
/// whether to show Auth, Onboarding, or the main tabs. Purely visual —
/// it doesn't gate on network state, so it can't get the user stuck.
struct SplashView: View {
    /// How long the splash stays on screen before RootView fades it out.
    static let minimumDuration: Duration = .milliseconds(1100)

    @State private var markScale: CGFloat = 0.7
    @State private var markOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glow = false

    var body: some View {
        ZStack {
            Brand.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
                FlickerMark(size: 96)
                    .scaleEffect(markScale)
                    .opacity(markOpacity)
                    .shadow(color: Brand.pink.opacity(glow ? 0.45 : 0.15), radius: glow ? 24 : 10)

                VStack(spacing: 4) {
                    Text("Flicker")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Share the moment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                markScale = 1.0
                markOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

#Preview {
    SplashView()
}
