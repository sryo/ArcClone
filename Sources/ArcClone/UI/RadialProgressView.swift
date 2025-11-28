import SwiftUI

struct RadialProgressView: View {
    let progress: CGFloat
    var icon: String = "plus"
    let size: CGFloat = 40
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 4, x: 0, y: 0)
            
            // Icon in center
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .opacity(Double(progress))
                .scaleEffect(0.5 + (0.5 * progress))
        }
        .padding(20)
    }
}
