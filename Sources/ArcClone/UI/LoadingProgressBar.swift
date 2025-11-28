import SwiftUI

struct LoadingProgressBar: View {
    @State private var progress: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: min(200, geometry.size.width * 0.3), height: 3)
                
                // Animated progress bar
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.8),
                                Color.accentColor
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: min(200, geometry.size.width * 0.3) * progress, height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 3)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Indeterminate animation that cycles the progress
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
            progress = 1.0
        }
        
        // Add a subtle pulsing effect
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                progress = 0.3
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.3)) {
                progress = 1.0
            }
        }
    }
}

#Preview {
    LoadingProgressBar()
        .frame(height: 50)
        .background(Color.gray.opacity(0.2))
}
