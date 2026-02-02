import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    @StateObject private var recorder = RecorderEngine()
    @StateObject private var pickerManager = RegionPickerManager()
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Screen Recorder")
                .font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Display:").font(.caption2).foregroundColor(.secondary)
                Picker("", selection: $recorder.selectedDisplay) {
                    ForEach(recorder.availableDisplays, id: \.self) { display in
                        Text("Display \(display.displayID)").tag(display as SCDisplay?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            HStack {
                Toggle("Audio", isOn: $recorder.recordAudio)
                Spacer()
                Toggle("Mic", isOn: $recorder.recordMicrophone)
            }
            .font(.caption)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Region:").font(.caption2).foregroundColor(.secondary)
                
                HStack {
                    TextField("X", text: $recorder.cropX)
                    TextField("Y", text: $recorder.cropY)
                    TextField("W", text: $recorder.cropW)
                    TextField("H", text: $recorder.cropH)
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                
                Button("Select Area") {
                    pickerManager.startPicking()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .onChange(of: pickerManager.cropRect) { _, newRect in
                    if let rect = newRect {
                        recorder.cropX = "\(Int(rect.origin.x))"
                        recorder.cropY = "\(Int(rect.origin.y))"
                        recorder.cropW = "\(Int(rect.size.width))"
                        recorder.cropH = "\(Int(rect.size.height))"
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Save to:").font(.caption2).foregroundColor(.secondary)
                Button(action: { recorder.selectOutputDirectory() }) {
                    HStack {
                        Image(systemName: "folder")
                        Text(recorder.outputDirectory.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            HStack {
                Toggle("GIF", isOn: $recorder.convertToGif)
                Spacer()
                HStack(spacing: 4) {
                    TextField("", value: $recorder.gifFps, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                    Text("FPS").font(.caption2)
                }
            }
            .font(.caption)
            
            HStack {
                if !recorder.isRecording {
                    Button(action: {
                        Task { await recorder.start() }
                    }) {
                        Label("Start Recording", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: {
                        Task { await recorder.stop() }
                    }) {
                        Label("Stop Recording", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
            }
            
            Text(recorder.status)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(width: 250)
        .onAppear {
            setupWindow()
        }
    }
    
    private func setupWindow() {
        // Small delay to ensure the window is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.title != "Region Picker" }) {
                window.level = .floating
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowFrame = window.frame
                    let newOrigin = NSPoint(
                        x: screenFrame.maxX - windowFrame.width - 20,
                        y: screenFrame.maxY - windowFrame.height - 20
                    )
                    window.setFrameOrigin(newOrigin)
                }
            }
        }
    }
}

@main
struct ScreenRecorderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
