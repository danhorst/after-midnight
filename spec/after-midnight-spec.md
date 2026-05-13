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

## Phase 2: macOS Menu Bar App (After Midnight.app) — COMPLETE

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

### Architecture

The app holds the gamma table in its own process — no hold subprocess needed.
`DarkroomMode.enableInProcess()` / `disableInProcess()` apply and restore the gamma table directly.
The CLI's subprocess approach is preserved for standalone use.

### Notes

- `am` CLI remains a first-class deliverable; both coexist via the shared `AfterMidnightCore` library.
- Login at login via `SMAppService`: works for apps installed in `~/Applications` or `/Applications` with ad-hoc signing.
- Intensity hardcoded to full red inversion; could be exposed as a preference in a future pass.

---

## Phase 3: Automation Support

### Goal

Allow darkroom mode to be triggered from outside the app — keyboard shortcuts, Shortcuts automations, scripts — without adding a settings UI to the menu bar app.

### Approach

**URL scheme** (`aftermidnight://`)
Register a custom URL scheme in `Info.plist`.
Handle `aftermidnight://toggle`, `aftermidnight://on`, `aftermidnight://off` via `onOpenURL`.
Immediately actionable from scripts, Alfred, Raycast, etc.

**Shortcuts actions** (App Intents, macOS 13+)
Expose `ToggleDarkroomIntent`, `EnableDarkroomIntent`, `DisableDarkroomIntent` via `AppIntentsPackage`.
Appears in the Shortcuts app and Spotlight; composable with other automations.
Users can assign a global keyboard shortcut to any Shortcut via System Settings — no in-app hotkey UI needed.

### What this avoids

A bespoke global hotkey would require a settings UI to configure and capture the key combination.
URL scheme + Shortcuts gives system-wide triggering via user-owned infrastructure instead.
