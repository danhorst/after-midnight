# After Midnight

A macOS utility that toggles "darkroom mode": a red-on-black display effect for working comfortably in a dark room.
Inspired by f.lux's darkroom mode and a nod to the classic After Dark screensaver.

---

## Phase 1: CLI Tool (`am`) — COMPLETE

### Goal

A Swift command-line tool that toggles darkroom mode on/off.
The executable is named `am` — both a CLI convention and a wink at AM time.

### Behavior

- Single invocation toggles state on/off
- State persists in `$TMPDIR/.am_active` (user-scoped, clears on reboot)
- Prints a brief status line on toggle: `After Midnight: ON` / `After Midnight: OFF`

### Implementation

The darkroom effect is applied via `CGSetDisplayTransferByTable` (CoreGraphics, public API).
This writes the hardware gamma LUT directly on all active displays: inverted red channel, zero green and blue.
White goes black, black goes red — the darkroom safelight effect.
No entitlements or user permissions are required.

`CGSetDisplayTransferByTable` is process-scoped: the OS restores the gamma table when the setting process exits.
To hold the effect, `enable()` launches a detached `--hold` subprocess of the same binary.
The subprocess applies the gamma table and blocks; `disable()` kills it by PID and the OS restores the display.
PID is tracked in `$TMPDIR/.am_pid`.

### What Was Ruled Out

The accessibility filter APIs were explored and rejected:

- `com.apple.universalaccess` preference writes are silently dropped by `cfprefsd` on Ventura+ for unsandboxed processes.
- Classic Invert and Color Filter are mutually exclusive even via API — `accessibilityd` enforces the same constraint the UI does.
- `MADisplayFilterPrefSetType` for Color Tint (type 5) silently falls back to grayscale regardless of call order or argument encoding.
- The standard accessibility color filters (grayscale, color blindness corrections) don't produce a usable darkroom effect.
- `UAControlsManager` and related `UniversalAccess.framework` symbols are not available from a CLI tool on macOS 15.

The gamma table approach produces a better result than the originally-specified "Classic Invert + red color tint" combination anyway: the inverted red channel gives white→black, black→red directly, with no intermediate compositing.

### Constraints

- macOS 13+ (Ventura)
- No App Store distribution; no private APIs in the final implementation
- No user permissions required

---

## Phase 2: macOS Menu Bar App (After Midnight.app)

### Goal

Wrap the Phase 1 toggle logic in a native macOS menu bar application.

### Behavior

- Lives in the menu bar; no Dock presence
- Single click or menu item toggles darkroom mode
- Icon reflects current state (e.g. filled/unfilled moon, or dim/bright star)
- Launches at login (optional, user-controlled)

### Design Direction

- Name: **After Midnight**
- Visual motif: moon, stars, or a midnight clock — something that evokes dark-adapted vision
- Minimal UI; this is a toggle utility, not a settings app
- The After Dark screensaver lineage is an intentional easter egg, not a primary design driver

### Architecture Decision Required

The Phase 1 hold subprocess re-executes the `am` binary by path (`CommandLine.arguments[0]`).
For a menu bar app, the hold process needs a stable, bundled binary path.
Two options:

| Option | Description | Trade-off |
| ------ | ----------- | --------- |
| Shared framework | `AfterMidnightCore` as a proper framework; both `am` and the app link it; the app manages its own hold loop via a background thread or GCD | No CLI binary needed inside the bundle; cleaner for the app; breaks the CLI `--hold` self-exec pattern |
| Bundled `am` binary | App bundles the `am` executable in `Contents/MacOS/`; app invokes it for toggle | CLI and app share the same binary; simpler; the app still needs its own `NSStatusItem` and lifecycle management |

The shared framework approach is likely cleaner for Phase 2, since the app's natural lifecycle (always running) eliminates the need for the hold-subprocess pattern entirely.
The app process itself holds the gamma table; toggling off simply calls `CGDisplayRestoreColorSyncSettings()`.

### Open Questions

- Intensity: currently hardcoded to full red inversion. Expose as a slider/preference, or keep hardcoded?
- Should the CLI `am` remain a first-class deliverable alongside the app, or become internal-only once the app exists?
- Login item implementation: `SMAppService` (macOS 13+) is the modern API; verify it works without a provisioning profile for a locally-signed app.
