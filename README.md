# After Midnight

Working late? Turn After Midnight on and keep your night vision intact.

This small, opinionated macOS menu bar app applies a red-on-black[^1] LUT to all displays.
No accessibility permissions needed.[^2]

## System Requirements

macOS 13 (Ventura) or later.

## Installation

```sh
brew tap danhorst/tap && brew install after-midnight
```

### Manual

Building this app yourself requires Xcode and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone git@github.com:danhorst/after-midnight.git
cd after-midnight
make install-app
```

This installs `After Midnight.app` to `~/Applications`.
Launch it once from there to register the App Intents with the system.

## In Use

### Menu bar

Choose “Turn On” from moon icon in the menu bar to enter darkroom mode.

Settings:
- **Invert Colors** flips the gamma curve so black goes red and white goes black. The default is red tint only—black stays black.
- **Launch at Login** registers the app via `SMAppService`.

### CLI

```sh
am           # toggle on/off
am --invert  # toggle with color inversion
```

The CLI and the app share state in `$TMPDIR/.am_active`.

### Automation

The app URL scheme is usable from scripts, Alfred, Raycast, etc.:

```sh
open aftermidnight://toggle
open aftermidnight://on
open aftermidnight://off
```

The Toggle, Enable, and Disable actions for After Midnight are available in the Shortcuts app.
A global keyboard shortcut can be assigned to any of them via System Settings → Keyboard → Keyboard Shortcuts → Shortcuts.

## Building

```sh
make generate    # create After Midnight.xcodeproj from project.yml
make build-app   # build the app bundle
make build       # CLI only (swift build -c release)
swift test       # run tests
```

> [!NOTE]
> `After Midnight.xcodeproj` is ignored git.
> Look at `project.yml` instead.

[^1]: This effect is similar to the “Darkroom” mode in [f.lux](https://justgetflux.com). If you use Night Shift, you don’t need the rest of the functions of f.lux.
[^2]: Writing a custom gamma LUT directly to the display hardware isn’t allowed from inside the macOS App Store sandbox.
