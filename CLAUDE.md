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
- Private APIs are acceptable (`UAControlsManager` / `UADisplay` or direct `com.apple.universalaccess` preference writes).
- Requires `com.apple.accessibility.api` entitlement.
- No App Store distribution.

## Open questions (from spec)

- Does `com.apple.accessibility.api` allow direct preference writes, or is a different approach needed?
- Do Classic Invert and Color Filters stack when set via API (the UI enforces mutual exclusion)?
- Is `UAControlsManager` accessible from a CLI tool without a full app bundle?
- Phase 2: shared framework target vs. bundled `am` binary?
- Tint intensity: hardcode red at 50% for MVP, or expose as a preference?

## Build and test

No Xcode project exists yet.
Once created, standard commands will be:

```
# Build CLI
swift build

# Run CLI
swift run am

# Build release
swift build -c release

# Run tests
swift test

# Run a single test
swift test --filter TestSuiteName/testMethodName
```

If the project uses an `.xcodeproj` or `.xcworkspace`, use `xcodebuild` instead.
