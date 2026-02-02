import SwiftUI

@MainActor
class RegionPickerManager: ObservableObject {
    @Published var cropRect: CGRect?
    @Published var isPicking = false
    
    private var window: NSWindow?
    
    func startPicking() {
        isPicking = true
        let screen = NSScreen.main!
        let window = NSWindow(contentRect: screen.frame,
                             styleMask: [.borderless],
                             backing: .buffered,
                             defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        
        let pickerView = RegionPickerView(onComplete: { rect in
            self.cropRect = rect
            self.stopPicking()
        })
        
        window.contentView = NSHostingView(rootView: pickerView)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
    
    func stopPicking() {
        isPicking = false
        window?.orderOut(nil)
        window = nil
    }
}

struct RegionPickerView: View {
    var onComplete: (CGRect) -> Void
    @State private var startPoint: CGPoint?
    @State private var endPoint: CGPoint?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .onContinuousHover { _ in } // To block interaction? Not needed for windows
            
            if let start = startPoint, let end = endPoint {
                let rect = CGRect(x: min(start.x, end.x),
                                  y: min(start.y, end.y),
                                  width: abs(end.x - start.x),
                                  height: abs(end.y - start.y))
                
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    endPoint = value.location
                }
                .onEnded { value in
                    if let start = startPoint {
                        let end = value.location
                        let rect = CGRect(x: min(start.x, end.x),
                                          y: min(start.y, end.y),
                                          width: abs(end.x - start.x),
                                          height: abs(end.y - start.y))
                        if rect.width > 5 && rect.height > 5 {
                            onComplete(rect)
                        } else {
                            onComplete(.zero)
                        }
                    }
                }
        )
        .onAppear {
            NSCursor.crosshair.set()
        }
        .onDisappear {
            NSCursor.arrow.set()
        }
    }
}
