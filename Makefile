.PHONY: build build-app install-app clean

RELEASE_DIR := .build/$(shell uname -m)-apple-macosx/release
APP_NAME    := After Midnight
APP_BUNDLE  := $(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications

build:
	swift build -c release

build-app:
	swift build -c release --product AfterMidnightApp
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(RELEASE_DIR)/AfterMidnightApp" "$(APP_BUNDLE)/Contents/MacOS/AfterMidnight"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep -s - "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

install-app: build-app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"

clean:
	rm -rf "$(APP_BUNDLE)" .build
