import SwiftUI

struct DownloadAnimationView: View {
    let id: UUID
    let startPoint: CGPoint
    let endPoint: CGPoint
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(.accentColor)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .modifier(FollowPathEffect(percent: progress, startPoint: startPoint, endPoint: endPoint))
            .opacity(1.0 - Double(progress) * 0.1) // Slight fade at very end
            .scaleEffect(1.0 - Double(progress) * 0.5) // Shrink as it approaches target
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    progress = 1.0
                }
                
                // Complete after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete()
                }
            }
    }
}

struct FollowPathEffect: GeometryEffect {
    var percent: CGFloat
    let startPoint: CGPoint
    let endPoint: CGPoint
    
    var animatableData: CGFloat {
        get { percent }
        set { percent = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let path = createPath()
        let point = pointOnPath(path, at: percent)
        return ProjectionTransform(CGAffineTransform(translationX: point.x - size.width / 2, y: point.y - size.height / 2))
    }
    
    private func createPath() -> Path {
        var path = Path()
        path.move(to: startPoint)
        
        // Calculate control point for a nice arc
        // We want it to go up and then down
        // Control point should be higher than the start point and somewhere between start and end x
        
        let midX = startPoint.x + (endPoint.x - startPoint.x) * 0.5
        // Peak height: significantly higher than start point to give a "toss" effect
        // If end point is lower (higher y), we need to go up first (lower y)
        let peakY = min(startPoint.y, endPoint.y) - 200
        
        let controlPoint = CGPoint(x: midX, y: peakY)
        
        path.addQuadCurve(to: endPoint, control: controlPoint)
        return path
    }
    
    private func pointOnPath(_ path: Path, at percent: CGFloat) -> CGPoint {
        // Simple quadratic bezier calculation since Path doesn't expose point(at:) easily without trimming
        // B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
        let t = percent
        let p0 = startPoint
        
        // Re-calculate control point (must match createPath)
        let midX = startPoint.x + (endPoint.x - startPoint.x) * 0.5
        let peakY = min(startPoint.y, endPoint.y) - 200
        let p1 = CGPoint(x: midX, y: peakY)
        
        let p2 = endPoint
        
        let x = pow(1-t, 2) * p0.x + 2 * (1-t) * t * p1.x + pow(t, 2) * p2.x
        let y = pow(1-t, 2) * p0.y + 2 * (1-t) * t * p1.y + pow(t, 2) * p2.y
        
        return CGPoint(x: x, y: y)
    }
}

struct DownloadAnimationContainer: View {
    @Binding var animations: [DownloadAnimation]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(animations) { animation in
                DownloadAnimationView(
                    id: animation.id,
                    startPoint: animation.startPoint,
                    endPoint: animation.endPoint,
                    onComplete: {
                        animations.removeAll { $0.id == animation.id }
                    }
                )
            }
        }
    }
}

struct DownloadAnimation: Identifiable {
    let id = UUID()
    let startPoint: CGPoint
    let endPoint: CGPoint
}
