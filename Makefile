.PHONY: generate build build-app install-app clean

DERIVED_DATA  := build/xcode
XCODE_RELEASE := $(DERIVED_DATA)/Build/Products/Release
APP_BUNDLE    := After Midnight.app
INSTALL_DIR   := $(HOME)/Applications

generate:
	xcodegen generate

build:
	swift build -c release

build-app: generate
	xcodebuild -project "After Midnight.xcodeproj" \
		-scheme "After Midnight" \
		-configuration Release \
		-derivedDataPath "$(DERIVED_DATA)" \
		build
	rm -rf "$(APP_BUNDLE)"
	cp -R "$(XCODE_RELEASE)/$(APP_BUNDLE)" .
	@echo "Built $(APP_BUNDLE)"

install-app: build-app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"

clean:
	rm -rf "$(APP_BUNDLE)" "AfterMidnight.app" .build build
