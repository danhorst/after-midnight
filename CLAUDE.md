# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOS utility that toggles "darkroom mode": a red-on-black display filter for working in a dark room.
Named **After Midnight** (`am` CLI binary) — a nod to f.lux's darkroom mode and the After Dark screensaver.

Full spec: `spec/after-midnight-spec.md`.

## Technical constraints

- macOS 13+ (Ventura) only.
- No App Store distribution.

## Implementation approach

The darkroom effect is applied via `CGSetDisplayTransferByTable` (CoreGraphics, public API — no entitlements required).
This writes the hardware gamma LUT directly on all active displays: inverted red channel, zero green and blue.
White goes black, black goes red — the darkroom safelight effect.
The change is process-scoped: cleared when the holding process exits or calls `CGDisplayRestoreColorSyncSettings()`.

The accessibility filter APIs (`com.apple.universalaccess` preferences, `UAControlsManager`, `MediaAccessibility`) were explored and rejected:
- `com.apple.universalaccess` writes are silently dropped by `cfprefsd` on Ventura+ for unsandboxed processes.
- Classic Invert and Color Filter are mutually exclusive even via API — `accessibilityd` enforces it.
- `MADisplayFilterPref` Color Tint (type 5) does not activate through the preference API; it silently falls back to grayscale.
- The standard accessibility filters don't produce a usable darkroom effect regardless.

## Architecture

`AfterMidnightCore` is a shared library used by both the CLI and the app.

**CLI (`am`)** — Swift executable, built via SPM.
Spawns a detached `--hold` subprocess of itself to keep the gamma table applied after the CLI exits.
State tracked in `$TMPDIR/.am_active` and `$TMPDIR/.am_pid`; clears on reboot.

**Menu bar app (`After Midnight.app`)** — SwiftUI `MenuBarExtra`, built via Xcode.
The app process itself holds the gamma table; no hold subprocess needed.
`DarkroomMode.enableInProcess()` / `disableInProcess()` manage the in-process lifecycle.
App Intents (Toggle, Enable, Disable) and the `aftermidnight://` URL scheme allow external control.
`project.yml` (xcodegen) is the committed source of truth; `After Midnight.xcodeproj` is gitignored.

## Structure

```
Package.swift                              — SPM: AfterMidnightCore library + am CLI + tests
project.yml                               — xcodegen spec for After Midnight.xcodeproj
Makefile                                  — generate, build, and install targets
Resources/Info.plist                      — app bundle metadata
Sources/
  AfterMidnightCore/DarkroomMode.swift   — toggle logic, shared by CLI and app
  am/main.swift                          — CLI entry point
  AfterMidnightApp/                      — menu bar app sources (compiled by Xcode)
Tests/
  AfterMidnightCoreTests/               — unit tests for core logic
```

## Build and test

```
make generate                            # regenerate After Midnight.xcodeproj from project.yml
make build                               # swift build -c release (CLI + library)
make build-app                           # xcodebuild release bundle with App Intents metadata
make install-app                         # build and install to ~/Applications
swift test                               # run all tests
swift test --filter DarkroomModeTests/testToggleOnFromInactive
```

The xcodeproj is gitignored; run `make generate` after pulling changes to `project.yml`.

## Release

1. Review `README.md` for accuracy against current behavior.
2. Write entries for the new version under `[Unreleased]` in `CHANGELOG.md`.
3. Commit all changes; working tree must be clean before the next step.
4. Run:
```
script/release VERSION
```

The script promotes `[Unreleased]` to a dated version entry, tags and pushes, computes the tarball sha256, updates `../homebrew-tap/Formula/after-midnight.rb`, and creates the GitHub release.
