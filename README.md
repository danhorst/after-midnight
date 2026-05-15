<img src="assets/After Midnight.png" width="128" alt="After Midnight icon">

# After Midnight

Working late?
Turn on After Midnight and keep your night vision intact.

This small, single-purpose macOS menu bar app applies a red-on-black[^1] LUT to all displays.[^2]

## System Requirements

macOS 13 (Ventura) or later.

## Installation

### App

Building the app requires Xcode and [xcodegen][1].

```sh
git clone git@github.com:danhorst/after-midnight.git
cd after-midnight
make install-app
```

The build script installs `After Midnight.app` in `/Applications`.
App Intents are registered with macOS when you run it for the first time.

### CLI

If you only want the CLI, you can install it from [my Homebrew tap][2]:

```sh
brew tap danhorst/tap && brew install after-midnight
```

## In Use

### Menu bar

Choose “Turn On” from moon icon in the menu bar to enter darkroom mode.

Settings:
- **Invert Colors** flips the gamma curve so black goes red and white goes black. The default is red tint only—black stays black.
- **Launch at Login** registers the app via `SMAppService`.

### CLI

```sh
am             # toggle on/off
am --invert    # switch to inverted mode (keeps running if already on)
am --no-invert # switch to red-tint mode (keeps running if already on)
```

The CLI and the app share active state (`$TMPDIR/.am_active`) and the invert preference (`com.danhorst.after-midnight` UserDefaults).
If the app is running, `am` delegates to it via the URL scheme rather than managing its own hold process.

### Automation

When the app is installed, it exposes a URL scheme that is callable from scripts, Alfred, Raycast, etc.:

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

[^1]: This effect is similar to the “Darkroom” mode in [f.lux][3]. If you use [Night Shift][4], you don’t need the rest of the functions of f.lux.
[^2]: Writing a custom gamma LUT directly to the display hardware isn’t allowed from inside the macOS App Store sandbox.

[1]: https://github.com/yonaskolb/XcodeGen
[2]: https://github.com/danhorst/homebrew-tap
[3]: https://justgetflux.com
[4]: https://en.wikipedia.org/wiki/Night_Shift_(software)
