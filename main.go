package main

import (
	"fmt"
	"image/color"
	"io"
	"os/exec"
	"regexp"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

var recordingCmd *exec.Cmd
var recordingStdin io.WriteCloser
var lastRecordedFile string

func stopRecording() error {
	if recordingCmd != nil && recordingCmd.Process != nil {
		if recordingStdin != nil {
			recordingStdin.Write([]byte("q"))
			recordingStdin.Close()
		}
		recordingCmd.Wait()
		recordingCmd = nil
		return nil
	}
	return nil
}

func startRecordingWithCrop(args []string, outputHandler func(string)) error {
	cmd := exec.Command("ffmpeg", args...)
	recordingCmd = cmd
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	recordingStdin = stdin
	stdout, _ := cmd.StdoutPipe()
	stderr, _ := cmd.StderrPipe()
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stdout.Read(buf)
			if n > 0 {
				outputHandler(string(buf[:n]))
			}
			if err != nil {
				break
			}
		}
	}()
	go func() {
		buf := make([]byte, 1024)
		for {
			n, err := stderr.Read(buf)
			if n > 0 {
				outputHandler(string(buf[:n]))
			}
			if err != nil {
				break
			}
		}
	}()
	return nil
}

// Custom widget for region selection
type RegionSelector struct {
	widget.BaseWidget
	start, end fyne.Position
	selecting  bool
	callback   func(x, y, w, h int)
	rect       *canvas.Rectangle
}

func NewRegionSelector(cb func(x, y, w, h int)) *RegionSelector {
	rs := &RegionSelector{callback: cb}
	rs.ExtendBaseWidget(rs)
	return rs
}

func (r *RegionSelector) CreateRenderer() fyne.WidgetRenderer {
	bg := canvas.NewRectangle(color.NRGBA{R: 0, G: 0, B: 0, A: 32})
	r.rect = canvas.NewRectangle(color.NRGBA{R: 0, G: 128, B: 255, A: 128})
	return widget.NewSimpleRenderer(container.NewWithoutLayout(bg, r.rect))
}

func (r *RegionSelector) Dragged(ev *fyne.DragEvent) {
	if !r.selecting {
		return
	}
	r.end = ev.Position
	r.updateRect()
}

func (r *RegionSelector) DragEnd() {
	if !r.selecting {
		return
	}
	r.selecting = false
	x := int(r.start.X)
	y := int(r.start.Y)
	w := int(r.end.X - r.start.X)
	h := int(r.end.Y - r.start.Y)
	if w < 0 {
		x, w = x+w, -w
	}
	if h < 0 {
		y, h = y+h, -h
	}
	if r.callback != nil {
		r.callback(x, y, w, h)
	}
	r.rect.Hide()
}

func (r *RegionSelector) Tapped(ev *fyne.PointEvent) {
	r.start = ev.Position
	r.end = ev.Position
	r.selecting = true
	r.rect.Show()
	r.updateRect()
}

func (r *RegionSelector) updateRect() {
	x := r.start.X
	y := r.start.Y
	w := r.end.X - r.start.X
	h := r.end.Y - r.start.Y
	if w < 0 {
		x, w = x+w, -w
	}
	if h < 0 {
		y, h = y+h, -h
	}
	r.rect.Move(fyne.NewPos(x, y))
	r.rect.Resize(fyne.NewSize(w, h))
	canvas.Refresh(r.rect)
}

func getAVFoundationDevices() (videoDevices, audioDevices map[string]string, videoLabels, audioLabels []string) {
	cmd := exec.Command("ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", "")
	output, err := cmd.CombinedOutput()
	if err != nil && len(output) == 0 {
		return
	}
	videoDevices = make(map[string]string)
	audioDevices = make(map[string]string)
	videoRe := regexp.MustCompile(`\[AVFoundation indev @ [^\]]+\] \[([0-9]+)\] (.+)$`)
	audioRe := regexp.MustCompile(`\[AVFoundation indev @ [^\]]+\] \[([0-9]+)\] (.+)$`)
	inVideo, inAudio := false, false
	for _, line := range regexp.MustCompile("\r?\n").Split(string(output), -1) {
		if regexp.MustCompile(`AVFoundation video devices:`).MatchString(line) {
			inVideo = true
			inAudio = false
			continue
		}
		if regexp.MustCompile(`AVFoundation audio devices:`).MatchString(line) {
			inAudio = true
			inVideo = false
			continue
		}
		if inVideo {
			if m := videoRe.FindStringSubmatch(line); m != nil {
				videoDevices[m[2]] = m[1]
				videoLabels = append(videoLabels, m[2])
			}
		}
		if inAudio {
			if m := audioRe.FindStringSubmatch(line); m != nil {
				audioDevices[m[2]] = m[1]
				audioLabels = append(audioLabels, m[2])
			}
		}
	}
	return
}

func main() {
	a := app.New()
	w := a.NewWindow("Screen Recorder")

	videoDevices, audioDevices, videoLabels, audioLabels := getAVFoundationDevices()
	if len(videoDevices) == 0 {
		videoDevices = map[string]string{"Screen 0": "1"}
		videoLabels = []string{"Nothing :("}
	}

	selectedVideo := "1"
	selectedAudio := "-1"
	recordAudio := false

	videoSelect := widget.NewSelect(videoLabels, func(label string) {
		selectedVideo = videoDevices[label]
	})
	videoSelect.SetSelected(videoLabels[1])

	audioSelect := widget.NewSelect(audioLabels, func(label string) {
		selectedAudio = audioDevices[label]
	})

	audioCheck := widget.NewCheck("Record Audio", func(checked bool) {
		recordAudio = checked
		if checked && len(audioLabels) > 0 {
			audioSelect.Enable()
			audioSelect.SetSelected(audioLabels[0])
		} else {
			audioSelect.Disable()
		}
	})
	audioSelect.Disable()

	// Add input fields for crop region
	xEntry := widget.NewEntry()
	xEntry.SetPlaceHolder("X")
	yEntry := widget.NewEntry()
	yEntry.SetPlaceHolder("Y")
	widthEntry := widget.NewEntry()
	widthEntry.SetPlaceHolder("Width")
	heightEntry := widget.NewEntry()
	heightEntry.SetPlaceHolder("Height")

	gifCheck := widget.NewCheck("Convert to GIF", nil)

	gifRateEntry := widget.NewEntry()
	gifRateEntry.SetPlaceHolder("GIF FPS (default 15)")
	gifRateEntry.SetText("15")

	status := widget.NewLabel("Ready to record")
	ffmpegCmdLabel := widget.NewLabel("")
	outputBox := widget.NewMultiLineEntry()
	outputBox.SetPlaceHolder("ffmpeg output will appear here...")
	isRecording := false
	startBtn := widget.NewButton("Start Recording", nil)
	stopBtn := widget.NewButton("Stop Recording", nil)
	startBtnContainer := container.NewVBox(startBtn)
	stopBtnContainer := container.NewVBox(stopBtn)
	stopBtnContainer.Hide()

	startBtn.OnTapped = func() {
		if isRecording {
			return
		}
		isRecording = true
		startBtnContainer.Hide()
		stopBtnContainer.Show()
		status.SetText("Recording...")
		output := fmt.Sprintf("record_%d.mp4", time.Now().Unix())

		lastRecordedFile = output
		cropArgs := ""
		x, y, w, h := xEntry.Text, yEntry.Text, widthEntry.Text, heightEntry.Text
		if x != "" && y != "" && w != "" && h != "" {
			cropArgs = fmt.Sprintf("crop=%s:%s:%s:%s", w, h, x, y)
		}
		args := []string{"-f", "avfoundation", "-framerate", "25", "-capture_cursor", "1"}
		input := selectedVideo
		if recordAudio && selectedAudio != "" {
			input = fmt.Sprintf("%s:%s", selectedVideo, selectedAudio)
		}
		args = append(args, "-i", input)
		if cropArgs != "" {
			args = append(args, "-vf", cropArgs)
		}
		args = append(args, output)
		ffmpegCmd := "ffmpeg " + fmt.Sprint(args)
		ffmpegCmdLabel.SetText(ffmpegCmd)
		outputBox.SetText("")
		err := startRecordingWithCrop(args, func(out string) {
			outputBox.SetText(outputBox.Text + out)
		})
		if err != nil {
			status.SetText("Failed to start: " + err.Error())
		} else {
			status.SetText("Recording... Output: " + output)
		}
	}
	stopBtn.OnTapped = func() {
		if !isRecording {
			return
		}
		isRecording = false
		stopBtnContainer.Hide()
		startBtnContainer.Show()
		status.SetText("Stopped.")
		err := stopRecording()
		if err != nil {
			status.SetText("Failed to stop: " + err.Error())
		} else {
			status.SetText("Stopped: " + lastRecordedFile)
			// Convert to GIF if checked
			if gifCheck.Checked && lastRecordedFile != "" {
				gifRate := gifRateEntry.Text
				if gifRate == "" {
					gifRate = "15"
				}
				gifFile := lastRecordedFile[:len(lastRecordedFile)-4] + ".gif"
				cmd := exec.Command("ffmpeg", "-i", lastRecordedFile, "-vf", fmt.Sprintf("fps=%s,scale=640:-1:flags=lanczos", gifRate), "-y", gifFile)
				out, err := cmd.CombinedOutput()
				outputBox.SetText(outputBox.Text + string(out))
				if err != nil {
					status.SetText("GIF conversion failed: " + err.Error())
				} else {
					status.SetText("GIF saved: " + gifFile)
				}
			}
		}
	}

	selectRegionBtn := widget.NewButton("Select Region Anywhere", func() {
		x, y, w, h := SelectRegion()
		xEntry.SetText(fmt.Sprintf("%d", x))
		yEntry.SetText(fmt.Sprintf("%d", y))
		widthEntry.SetText(fmt.Sprintf("%d", w))
		heightEntry.SetText(fmt.Sprintf("%d", h))
	})

	w.SetContent(container.NewVBox(
		widget.NewLabel("Screen Recorder for macOS (uses ffmpeg)"),
		widget.NewLabel("Select Screen:"),
		videoSelect,
		widget.NewLabel("Audio Options:"),
		audioCheck,
		audioSelect,
		widget.NewLabel("Select Region (leave blank for full screen):"),
		container.NewGridWithColumns(4, xEntry, yEntry, widthEntry, heightEntry),
		selectRegionBtn,
		container.NewGridWithColumns(3, gifCheck, gifRateEntry),
		startBtnContainer,
		stopBtnContainer,
		status,
		// ffmpegCmdLabel,
		// outputBox,
	))
	w.Resize(fyne.NewSize(400, 300))
	w.ShowAndRun()
}
