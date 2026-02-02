import Foundation
import ScreenCaptureKit
import AVFoundation

@MainActor
class RecorderEngine: ObservableObject {
    @Published var isRecording = false
    @Published var availableDisplays: [SCDisplay] = []
    @Published var selectedDisplay: SCDisplay?
    @Published var recordAudio = true
    @Published var recordMicrophone = true
    @Published var convertToGif = false
    @Published var gifFps = 15
    @Published var status = "Ready"
    
    @Published var cropX = ""
    @Published var cropY = ""
    @Published var cropW = ""
    @Published var cropH = ""
    
    @Published var outputDirectory: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var outputFile: URL?
    private let captureDelegate = CaptureDelegate()
    
    init() {
        Task {
            await updateAvailableContent()
        }
    }
    
    func updateAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableDisplays = content.displays
            if self.selectedDisplay == nil {
                self.selectedDisplay = content.displays.first
            }
            print("Found \(content.displays.count) displays and \(content.windows.count) windows")
        } catch {
            self.status = "Failed to get displays: \(error.localizedDescription)"
        }
    }
    
    func start() async {
        guard let display = selectedDisplay else {
            status = "No display selected"
            return
        }
        
        print("Starting recording for display: \(display.displayID)")
        
        var sourceRect = CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
        if let x = Double(cropX), let y = Double(cropY), let w = Double(cropW), let h = Double(cropH) {
            // Normalize width and height to be even numbers for H.264
            let normalizedW = floor(w / 2) * 2
            let normalizedH = floor(h / 2) * 2
            sourceRect = CGRect(x: x, y: y, width: normalizedW, height: normalizedH)
            print("Using crop rect: \(sourceRect)")
        }
        
        let path = NSTemporaryDirectory() + "capture_\(Int(Date().timeIntervalSince1970)).mp4"
        let url = URL(fileURLWithPath: path)
        self.outputFile = url
        
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(sourceRect.width),
                AVVideoHeightKey: Int(sourceRect.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vInput.expectsMediaDataInRealTime = true
            writer.add(vInput)
            
            var aInput: AVAssetWriterInput?
            if recordAudio {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128000
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = true
                writer.add(input)
                aInput = input
            }
            
            var mInput: AVAssetWriterInput?
            if recordMicrophone {
                let micSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 1, // Mic is often mono
                    AVEncoderBitRateKey: 64000
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
                input.expectsMediaDataInRealTime = true
                writer.add(input)
                mInput = input
            }
            
            if writer.startWriting() {
                print("AssetWriter started writing to \(url.path)")
            } else {
                print("AssetWriter failed to start writing: \(writer.error?.localizedDescription ?? "unknown error")")
            }
            
            captureDelegate.prepare(writer: writer, videoInput: vInput, audioInput: aInput, micInput: mInput)
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(sourceRect.width)
            config.height = Int(sourceRect.height)
            config.sourceRect = sourceRect
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.capturesAudio = recordAudio
            config.captureMicrophone = recordMicrophone
            config.sampleRate = 48000
            config.channelCount = 2
            
            stream = SCStream(filter: filter, configuration: config, delegate: captureDelegate)
            try stream?.addStreamOutput(captureDelegate, type: .screen, sampleHandlerQueue: .global())
            if recordAudio {
                try stream?.addStreamOutput(captureDelegate, type: .audio, sampleHandlerQueue: .global())
            }
            if recordMicrophone {
                try stream?.addStreamOutput(captureDelegate, type: .microphone, sampleHandlerQueue: .global())
            }
            
            try await stream?.startCapture()
            
            isRecording = true
            status = "Recording..."
            assetWriter = writer
            print("Capture stream started")
        } catch {
            status = "Error: \(error.localizedDescription)"
            print("Start error: \(error)")
        }
    }
    
    func stop() async {
        print("Stopping recording...")
        
        // Stop the stream first, ignoring errors if it's already stopped
        do {
            try await stream?.stopCapture()
        } catch {
            print("Stop stream error (likely already stopped): \(error.localizedDescription)")
        }
        
        // Ensure we mark as inactive and finish inputs
        isRecording = false
        captureDelegate.finish()
        
        // Finish writing to the file
        if let writer = assetWriter {
            print("Finishing AssetWriter...")
            await writer.finishWriting()
            if let error = writer.error {
                print("AssetWriter finished with error: \(error.localizedDescription)")
            }
        }
        
        // Move file to output directory
        if let outputFile = outputFile {
            let finalVideoUrl = outputDirectory.appendingPathComponent(outputFile.lastPathComponent)
            try? FileManager.default.removeItem(at: finalVideoUrl)
            do {
                try FileManager.default.moveItem(at: outputFile, to: finalVideoUrl)
                status = "Video saved to \(outputDirectory.lastPathComponent)"
                print("Video moved to \(finalVideoUrl.path)")
                
                if convertToGif {
                    status = "Converting to GIF..."
                    let gifUrl = finalVideoUrl.deletingPathExtension().appendingPathExtension("gif")
                    await convertToGifProcess(input: finalVideoUrl, output: gifUrl)
                    status = "Video and GIF saved to Desktop"
                }
            } catch {
                status = "Failed to save file: \(error.localizedDescription)"
                print("Move item error: \(error)")
            }
        }
    }
    
    private func convertToGifProcess(input: URL, output: URL) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        if !FileManager.default.fileExists(atPath: process.executableURL!.path) {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ffmpeg")
        }
        if !FileManager.default.fileExists(atPath: process.executableURL!.path) {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        }
        
        process.arguments = [
            "-i", input.path,
            "-vf", "fps=\(gifFps),scale=640:-1:flags=lanczos",
            "-y", output.path
        ]
        
        try? process.run()
        process.waitUntilExit()
    }
    
    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                outputDirectory = url
            }
        }
    }
}

class CaptureDelegate: NSObject, SCStreamDelegate, SCStreamOutput {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var startTime: CMTime?
    private let queue = DispatchQueue(label: "com.recorder.captureQueue")
    private var isActive = false
    private var videoFrameCount = 0
    private var audioSampleCount = 0
    private var micSampleCount = 0
    
    func prepare(writer: AVAssetWriter, videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput?, micInput: AVAssetWriterInput? = nil) {
        queue.sync {
            self.assetWriter = writer
            self.videoInput = videoInput
            self.audioInput = audioInput
            self.micInput = micInput
            self.startTime = nil
            self.isActive = true
            self.videoFrameCount = 0
            self.audioSampleCount = 0
            self.micSampleCount = 0
        }
    }
    
    func finish() {
        queue.sync {
            self.isActive = false
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            self.micInput?.markAsFinished()
            print("Capture finished. Frames: \(videoFrameCount), Audio: \(audioSampleCount), Mic: \(micSampleCount)")
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error.localizedDescription)")
    }
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .screen {
            processVideo(sampleBuffer)
        } else if type == .audio {
            processAudio(sampleBuffer, isMic: false)
        } else if type == .microphone {
            processAudio(sampleBuffer, isMic: true)
        }
    }
    
    private func processVideo(_ sampleBuffer: CMSampleBuffer) {
        queue.async {
            guard self.isActive, let writer = self.assetWriter else { return }
            if writer.status == .failed { return }
            
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[AnyHashable: Any]],
                  let attachment = attachments.first,
                  let statusRawValue = attachment[SCStreamFrameInfo.status.rawValue] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete else {
                return
            }
            
            if self.startTime == nil {
                if CMSampleBufferGetImageBuffer(sampleBuffer) == nil { return }
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                self.startTime = time
                writer.startSession(atSourceTime: time)
                print("Writing session started at \(time.seconds)")
            }
            
            if let input = self.videoInput, input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    print("Failed to append video frame (Status: \(writer.status.rawValue)): \(writer.error?.localizedDescription ?? "unknown")")
                } else {
                    self.videoFrameCount += 1
                }
            }
        }
    }
    
    private func processAudio(_ sampleBuffer: CMSampleBuffer, isMic: Bool) {
        queue.async {
            guard self.isActive, let writer = self.assetWriter else { return }
            if writer.status == .failed { return }
            
            if self.startTime == nil { return } // Wait for video to start session
            
            let input = isMic ? self.micInput : self.audioInput
            if let input = input, input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    print("Failed to append \(isMic ? "mic" : "audio") sample (Status: \(writer.status.rawValue)): \(writer.error?.localizedDescription ?? "unknown")")
                } else {
                    if isMic { self.micSampleCount += 1 } else { self.audioSampleCount += 1 }
                }
            }
        }
    }
}
