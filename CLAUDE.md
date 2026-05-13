# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOS utility that toggles "darkroom mode": Classic color invert + red color tint filter.
Named **After Midnight** (`am` CLI binary) — a nod to f.lux's darkroom mode and the After Dark screensaver.

Full spec: `spec/after-midnight-spec.md`.

## Architecture

Two-phase project; Phase 1 is the prerequisite for Phase 2.

**Phase 1 — CLI tool (`am`)**
Swift command-line executable.
Reads/writes `com.apple.universalaccess` preferences to activate Classic Invert + Color Tint (type 5, red at ~50% opacity).
Toggles state on each invocation; persistence via `$TMPDIR/.am_active` (clears on reboot).
Prints `After Midnight: ON` / `After Midnight: OFF`.

**Phase 2 — Menu bar app (`After Midnight.app`)**
Wraps Phase 1 toggle logic in an `NSStatusItem`-based app (no Dock presence).
Icon reflects active state.
Phase 1 work should be structured so the app layer can reuse it (shared framework target or bundled binary — TBD per spec open questions).

## Technical constraints

- macOS 13+ (Ventura) only.
- No App Store distribution.

## Implementation approach

The darkroom effect is applied via `CGSetDisplayTransferByTable` (CoreGraphics, public API — no entitlements required).
This writes the hardware gamma LUT directly on all active displays: inverted red channel, zero green and blue.
White goes black, black goes red — the darkroom safelight effect.
The change persists after the process exits and is cleared by `CGDisplayRestoreColorSyncSettings()`.

The accessibility filter APIs (`com.apple.universalaccess` preferences, `UAControlsManager`, `MediaAccessibility`) were explored and rejected:
- `com.apple.universalaccess` writes are silently dropped by `cfprefsd` on Ventura+ for unsandboxed processes.
- Classic Invert and Color Filter are mutually exclusive even via API — `accessibilityd` enforces it.
- `MADisplayFilterPref` Color Tint (type 5) does not activate through the preference API; it silently falls back to grayscale.
- The standard accessibility filters don't produce a usable darkroom effect regardless.

## Open questions (from spec)

- Phase 2: shared framework target vs. bundled `am` binary?
- Tint intensity: currently hardcoded to full red. Expose as a preference?

## Structure

Swift Package Manager project.
`AfterMidnightCore` is the library target; `am` is the CLI executable that depends on it.
Tests live in `Tests/AfterMidnightCoreTests/`.

```
Package.swift
Sources/
  AfterMidnightCore/DarkroomMode.swift   — toggle logic
  am/main.swift                          — CLI entry point
Tests/
  AfterMidnightCoreTests/               — unit tests for core logic
```

## Build and test

```
swift build                              # build everything
swift run am                             # toggle darkroom mode
swift build -c release                   # release build
swift test                               # run all tests
swift test --filter DarkroomModeTests/testToggleOnFromInactive
```
