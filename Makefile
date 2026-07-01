# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/WhisperPro-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
LOCAL_DERIVED_DATA := $(CURDIR)/.local-build

.PHONY: all clean whisper setup build local signed check healthcheck help dev run

# Stable signed dev build: signed with your Apple Development cert so macOS
# permissions (Accessibility, Microphone) survive every rebuild — grant once.
#
# Your personal signing identity is kept OUT of the repo. Put your own values in an
# untracked Makefile.local (it overrides the placeholders below):
#   SIGN_IDENTITY := Apple Development: you@example.com (YOURTEAMID)
#   DEV_TEAM := YOURTEAMID
# Find your identity with:  security find-identity -v -p codesigning
SIGN_IDENTITY := Apple Development
DEV_TEAM :=
SIGNED_APP := /Applications/Whisper Pro.app
# Build under the bundle id the app's live data (transcripts, stats, streak,
# settings) already lives under, so the signed build keeps that history instead
# of starting fresh under a separate identity.
APP_BUNDLE_ID := com.prakashjoshipax.WhisperPro

# Local, untracked overrides (your personal SIGN_IDENTITY / DEV_TEAM). Optional;
# silently skipped if absent.
-include Makefile.local

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro" -configuration Debug CODE_SIGN_IDENTITY="" build

# Build for local use without Apple Developer certificate
local: check setup
	@echo "Building Whisper Pro for local use (no Apple Developer certificate required)..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	xcodebuild -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro" -configuration Debug \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		ENABLE_DEBUG_DYLIB=NO \
		CODE_SIGN_ENTITLEMENTS="$(CURDIR)/Whisper Pro/WhisperPro.local.entitlements" \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Debug/Whisper Pro.app" && \
	if [ -d "$$APP_PATH" ]; then \
		echo "Copying Whisper Pro.app to ~/Downloads..."; \
		rm -rf "$$HOME/Downloads/Whisper Pro.app"; \
		ditto "$$APP_PATH" "$$HOME/Downloads/Whisper Pro.app"; \
		xattr -cr "$$HOME/Downloads/Whisper Pro.app"; \
		echo ""; \
		echo "Build complete! App saved to: ~/Downloads/Whisper Pro.app"; \
		echo "Run with: open ~/Downloads/Whisper Pro.app"; \
		echo ""; \
		echo "Limitations of local builds:"; \
		echo "  - No iCloud dictionary sync"; \
		echo "  - No automatic updates (pull new code and rebuild to update)"; \
	else \
		echo "Error: Could not find built Whisper Pro.app at $$APP_PATH"; \
		exit 1; \
	fi

sync-api-keys:
	@echo "API keys are entered in the app's settings and stored per-user — nothing to sync."

signed: check setup sync-api-keys
	@echo "Building signed dev build (stable Apple Development signature)..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	xcodebuild -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro" -configuration Debug \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		PRODUCT_BUNDLE_IDENTIFIER="$(APP_BUNDLE_ID)" \
		ENABLE_DEBUG_DYLIB=NO \
		CODE_SIGN_ENTITLEMENTS="$(CURDIR)/Whisper Pro/WhisperPro.local.entitlements" \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Debug/Whisper Pro.app" && \
	if [ ! -d "$$APP_PATH" ]; then echo "Error: build product not found"; exit 1; fi && \
	echo "Killing any running instances..." && \
	pkill -x "Whisper Pro" 2>/dev/null; pkill -x "Whisper" 2>/dev/null; sleep 1; \
	echo "Installing to $(SIGNED_APP)..." && \
	mkdir -p "$(SIGNED_APP)" && \
	rsync -a --delete "$$APP_PATH/" "$(SIGNED_APP)/" && \
	xattr -cr "$(SIGNED_APP)" && \
	echo "Re-signing with your Apple Development cert..." && \
	codesign --force --deep --options runtime \
		--entitlements "$(CURDIR)/Whisper Pro/WhisperPro.local.entitlements" \
		--sign "$(SIGN_IDENTITY)" "$(SIGNED_APP)" && \
	echo "" && \
	echo "Done. Launching $(SIGNED_APP)" && \
	open "$(SIGNED_APP)" && \
	echo "" && \
	echo ">> First time only: grant Accessibility + Microphone to 'Whisper Pro Dev'." && \
	echo ">> Every future 'make signed' keeps the same signature — no re-granting."

# Run application
run:
	@if [ -d "$$HOME/Downloads/Whisper Pro.app" ]; then \
		echo "Opening ~/Downloads/Whisper Pro.app..."; \
		open "$$HOME/Downloads/Whisper Pro.app"; \
	else \
		echo "Looking for Whisper Pro.app in DerivedData..."; \
		APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "Whisper Pro.app" -type d | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Found app at: $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "Whisper Pro.app not found. Please run 'make build' or 'make local' first."; \
			exit 1; \
		fi; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to Whisper Pro project"
	@echo "  build              Build the Whisper Pro Xcode project"
	@echo "  local              Build for local use (no Apple Developer certificate needed)"
	@echo "  run                Launch the built Whisper Pro app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  all                Run full build process (default)"
	@echo "  clean              Remove build artifacts"
	@echo "  help               Show this help message"
