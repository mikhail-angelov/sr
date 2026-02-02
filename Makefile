APP_NAME = ScreenRecorder
BUILD_DIR = .build
RELEASE_BIN = $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE = $(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
PLIST = Sources/Info.plist

.PHONY: all build bundle install clean

all: build bundle

build:
	swift build -c release

bundle: build
	mkdir -p $(MACOS_DIR)
	mkdir -p $(CONTENTS_DIR)/Resources
	cp $(RELEASE_BIN) $(MACOS_DIR)/
	cp $(PLIST) $(CONTENTS_DIR)/Info.plist

install: bundle
	rm -rf /Applications/$(APP_BUNDLE)
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Successfully installed $(APP_NAME) to /Applications"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
