# Native Swift Screen Recorder

A high-performance, native macOS screen recording application built with **Swift**, **SwiftUI**, and **ScreenCaptureKit**. This app provides high-fidelity video and audio capture with a minimal screen footprint.

![image](https://github.com/user-attachments/assets/a3fd4f7a-ed3c-41e6-ab02-b016a6c471da)

## Features

- **Native Performance**: Built using Apple's latest `ScreenCaptureKit` for low-latency, high-quality recording.
- **Audio Capture**: Support for concurrent System Audio and Microphone recording (48kHz high-fidelity).
- **Flexible Region Selection**: Record your entire display or a specific cropped region using a native crosshair selector.
- **Ultra-Compact UI**: Minimalist interface that stays "Always on Top" and defaults to the top-right corner of your screen.
- **GIF Conversion**: Automatically convert your recordings to high-quality GIFs.
- **Customizable Output**: Choose your save location (defaults to Downloads).

## Requirements

- **macOS 15.0 (Sequoia)** or later.
- **Xcode 16.0+** or **Swift 6.0+** (if building from source).
- **ffmpeg** (required for GIF conversion): `brew install ffmpeg`.

## Installation

### Option 1: Download Pre-built Binary (Recommended)
1. Go to the [Releases](https://github.com/mikhail-angelov/sr/releases) page.
2. Download the latest `ScreenRecorder.zip`.
3. Extract the zip file and move the `ScreenRecorder.app` to your Applications folder.
4. Double-click the app to run it—**no terminal window required!**

### Option 2: Build from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/mikhail-angelov/sr.git
   cd sr
   ```
2. Build and run via Swift Package Manager:
   ```bash
   swift run
   ```
3. To build a production release binary:
   ```bash
   swift build -c release
   # The binary will be at .build/release/ScreenRecorder
   ```

## Usage

1. **Permissions**: On first launch, macOS will ask for **Screen Recording** and **Microphone** permissions. Please grant these in System Settings.
2. **Setup**: Select the display you want to record and toggle Audio/Mic settings as needed.
3. **Region**: Click "Select Area" to draw a crop region on your screen.
4. **Output**: Click the folder icon to change where your videos are saved.
5. **Record**: Click **Start** to begin. The compact window will stay on top while you work. Click **Stop** when finished.

## License

MIT
