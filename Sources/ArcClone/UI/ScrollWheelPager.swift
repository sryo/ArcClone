import SwiftUI
import AppKit

struct ScrollWheelPager: NSViewRepresentable {
    enum OverscrollSide {
        case start // Library side (left)
        case end   // New Space side (right)
    }
    
    @Binding var visualPageIndex: CGFloat
    @Binding var targetPageIndex: Int
    let pageCount: Int
    let pageWidth: CGFloat
    let onSnap: (Int) -> Void
    var onOverscroll: ((OverscrollSide, CGFloat, CGPoint)?) -> Void = { _ in }
    
    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.parent = self
        return view
    }
    
    func updateNSView(_ nsView: ScrollWheelView, context: Context) {
        nsView.parent = self
    }
    
    class ScrollWheelView: NSView {
        var parent: ScrollWheelPager?
        private var accumulatedDelta: CGFloat = 0
        private var isScrolling = false
        private var overscrollAccumulator: CGFloat = 0
        private var currentOverscrollSide: OverscrollSide?
        
        override var acceptsFirstResponder: Bool { true }
        
        private var monitor: Any?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            setupMonitor()
        }
        
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                removeMonitor()
            }
        }
        
        private func setupMonitor() {
            removeMonitor()
            if window == nil { return }
            
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                return self?.handleEvent(event) ?? event
            }
        }
        
        private func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
        
        private func handleEvent(_ event: NSEvent) -> NSEvent? {
            guard let parent = parent else { return event }
            
            // Check if mouse is over this view
            let locationInWindow = event.locationInWindow
            let localPoint = self.convert(locationInWindow, from: nil)
            if !self.bounds.contains(localPoint) {
                return event
            }
            
            // Only handle horizontal scrolls
            if abs(event.scrollingDeltaX) < abs(event.scrollingDeltaY) {
                // Vertical scroll - let it pass
                return event
            }
            
            // Phase handling
            if event.phase == .began {
                isScrolling = true
                accumulatedDelta = 0
                overscrollAccumulator = 0
                currentOverscrollSide = nil
            }
            
            if event.phase == .changed {
                let delta = event.scrollingDeltaX
                accumulatedDelta += delta
                
                // Normal paging logic
                let progress = accumulatedDelta / parent.pageWidth
                parent.visualPageIndex = CGFloat(parent.targetPageIndex) - progress
                
                // Overscroll detection
                var isOverscrolling = false
                
                // Check End (New Space) - Right side
                if parent.targetPageIndex == parent.pageCount - 1 && delta < 0 {
                    if parent.visualPageIndex >= CGFloat(parent.pageCount - 1) - 0.01 {
                        isOverscrolling = true
                        currentOverscrollSide = .end
                    }
                }
                // Check Start (Library) - Left side
                else if parent.targetPageIndex == 0 && delta > 0 {
                    if parent.visualPageIndex <= 0.01 {
                        isOverscrolling = true
                        currentOverscrollSide = .start
                    }
                }
                
                if isOverscrolling, let side = currentOverscrollSide {
                    overscrollAccumulator += abs(delta)
                    
                    // Threshold to start showing progress
                    let startThreshold: CGFloat = 40
                    // Distance to complete the action
                    let completeDistance: CGFloat = 120
                    
                    if overscrollAccumulator > startThreshold {
                        let overscrollProgress = min(1.0, (overscrollAccumulator - startThreshold) / completeDistance)
                        parent.onOverscroll((side, overscrollProgress, locationInWindow))
                    }
                } else {
                    // Reset if direction changes or not at edge
                    if overscrollAccumulator > 0 {
                        overscrollAccumulator = 0
                        parent.onOverscroll(nil)
                        currentOverscrollSide = nil
                    }
                }
            }
            
            // Handle end of gesture
            
            // 1. Momentum started or is active (user released fingers)
            if event.momentumPhase.rawValue > 0 {
                if isScrolling {
                    snapToNearest()
                    isScrolling = false
                    resetOverscroll()
                }
            }
            // 2. Hard stop (no momentum)
            else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                if event.momentumPhase.rawValue == 0 {
                    if isScrolling {
                        snapToNearest()
                        isScrolling = false
                        resetOverscroll()
                    }
                }
            }
            
            // Consume the event to prevent other views from reacting
            return nil
        }
        
        private func resetOverscroll() {
            overscrollAccumulator = 0
            currentOverscrollSide = nil
            parent?.onOverscroll(nil)
        }
        
        private func snapToNearest() {
            guard let parent = parent else { return }
            
            // Determine target based on accumulated delta (velocity/distance)
            // If moved significantly, snap to next/prev
            let threshold = parent.pageWidth * 0.15 // 15% threshold for swipe
            
            var newIndex = parent.targetPageIndex
            
            if accumulatedDelta < -threshold {
                // Swiped left (fingers left, content moves left, index increases)
                newIndex += 1
            } else if accumulatedDelta > threshold {
                // Swiped right
                newIndex -= 1
            }
            
            // Clamp
            newIndex = max(0, min(newIndex, parent.pageCount - 1))
            
            // Notify parent to animate/snap
            parent.onSnap(newIndex)
            accumulatedDelta = 0
        }
    }
}
