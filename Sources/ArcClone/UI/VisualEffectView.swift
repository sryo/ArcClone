import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var tintColor: NSColor? = nil
    var tintOpacity: CGFloat = 0
    var drawsBackground: Bool = true
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .followsWindowActiveState
        visualEffectView.wantsLayer = true
        applyTint(to: visualEffectView)
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.isEmphasized = drawsBackground
        applyTint(to: visualEffectView)
    }
    
    private func applyTint(to view: NSVisualEffectView) {
        view.isEmphasized = drawsBackground
        view.material = material
        view.blendingMode = blendingMode
        view.layer?.backgroundColor = nil
        if let tintColor {
            view.layer?.backgroundColor = tintColor.withAlphaComponent(tintOpacity).cgColor
        }
    }
}
