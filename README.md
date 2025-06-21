# macOS Screen Recorder (Go + Fyne + ffmpeg)

This is another semi-vibecoding project: desktop application for macOS to record your screen (with optional audio and region selection), built with Go, Fyne, and ffmpeg.

## Features
- Select screen and audio device (auto-detected)
- Select full screen or region (by mouse, with live feedback)
- Record mouse cursor
- Start/Stop recording with clear UI
- Convert recording to GIF at custom frame rate
- View ffmpeg command and output in the app

## Requirements
- macOS (tested on Apple Silicon and Intel)
- [Go](https://golang.org/dl/) 1.18+
- [ffmpeg](https://ffmpeg.org/) (`brew install ffmpeg`)
- Xcode Command Line Tools (`xcode-select --install`)
- Fyne Go library (`go get fyne.io/fyne/v2`)

## Build & Run
1. Clone this repo and open the directory.
2. Install dependencies:
   ```sh
   go mod tidy
   ```
3. Build and run:
   ```sh
   go run .
   # or to build a binary
   go build -o screenrec .
   ./screenrec
   ```

## Usage
- Select your video and audio device from the dropdowns.
- (Optional) Select a region by mouse.
- Click **Start Recording**. The button will hide and **Stop Recording** will appear.
- Click **Stop Recording** to finish. If GIF conversion is enabled, a GIF will be created.
- The ffmpeg command and output will be shown in the app.

## Permissions
- On first run, macOS will prompt for screen recording permissions. Grant access in **System Settings > Privacy & Security > Screen Recording**.

## Notes
- The app uses ffmpeg's `avfoundation` input. Device indices and names are auto-detected.
- For region selection, a native macOS overlay is used.
- For GIF conversion, ffmpeg is called after recording stops.

## License
MIT
