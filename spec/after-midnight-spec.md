# After Midnight

A macOS utility that toggles "darkroom mode": Classic color invert + red color tint filter, for working comfortably in a dark room. Inspired by f.lux's darkroom mode and a nod to the classic After Dark screensaver.

---

## Phase 1: CLI Tool (`am`)

### Goal

A Swift command-line tool that toggles darkroom mode on/off. The executable is named `am` — both a CLI convention and a wink at AM time.

### Behavior

- Single invocation toggles state on/off
- State persists in `$TMPDIR/.am_active` (user-scoped, clears on reboot)
- Prints a brief status line on toggle: `After Midnight: ON` / `After Midnight: OFF`

### Technical Approach to Investigate

- `UAControlsManager` / `UADisplay` private framework (what f.lux uses)
- Or `AXUIElementCreateSystemWide()` + setting kAX attributes
- Check whether the `com.apple.accessibility.api` entitlement unlocks direct preference writes
- Determine whether a full `.app` bundle is required for private API access, or if a CLI tool suffices

### Target Settings

| Key                  | Value                                                          |
| -------------------- | -------------------------------------------------------------- |
| `classicInvert`      | `true`                                                         |
| `colorFilterEnabled` | `true`                                                         |
| `colorFilterType`    | `5` (Color Tint)                                               |
| `colorTint`          | `"1 0 0 0.5"` (red, 50% opacity — intensity TBD via testing) |

All keys under `com.apple.universalaccess`.

### Constraints

- macOS 13+ (Ventura)
- No App Store distribution required; private APIs are acceptable
- Minimize required user permissions — ideally Accessibility access granted once

### Open Questions

- Does the `com.apple.accessibility.api` entitlement allow direct preference writes?
- Do Classic Invert and Color Filters actually stack when set via API (bypassing UI mutual-exclusion logic)?
- Is `UAControlsManager` accessible without a full app bundle?

---

## Phase 2: macOS Menu Bar App (After Midnight.app)

### Goal

Wrap the Phase 1 toggle logic in a native macOS menu bar application. The CLI harness developed in Phase 1 should inform and be reusable by the app layer.

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

### Open Questions

- Should the app bundle Phase 1's `am` binary for CLI access, or share a common framework target?
- Tint color and intensity: expose as a preference, or hardcode red for MVP?
