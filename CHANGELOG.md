# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Sharpened smaller icon sizes

## [0.2.4] - 2026-05-15

### Fixed

- Display filter now persists through monitor configuration changes (connect, disconnect, sleep/wake).

## [0.2.3] - 2026-05-14

### Changed

- Install to system Applications folder instead of user Applications folder.

## [0.2.2] - 2026-05-14

### Added

- App icon.

## [0.2.1] - 2026-05-14

### Added

- Command-T keyboard shortcut for the Turn On / Turn Off menu item.

## [0.2.0] - 2026-05-14

### Added

- `--no-invert` flag to revert to red-tint mode from the CLI.
- Invert preference is now shared between CLI and app via the `com.danhorst.after-midnight` UserDefaults domain.
- App takes over a CLI-initiated session on launch: kills the hold subprocess and applies gamma in-process with the active mode.
- CLI delegates to the running app via URL scheme (`aftermidnight://on`, `aftermidnight://off`) when the app is open.

### Changed

- `am --invert` and `am --no-invert` while darkroom is active now change the display mode and keep the session running, rather than toggling off.

### Fixed

- `--invert` had no effect: the hold subprocess silently failed to spawn because `argv[0]` is a bare name when resolved via PATH.
- Disabling darkroom could terminate the calling process when the hold subprocess had failed to start, leaving PID 0 in the state file (`kill(0, SIGTERM)` signals the entire process group).
- Quitting the app while darkroom was active left the state file in place, causing the CLI to toggle off rather than on.

## [0.1.0] - 2026-05-13

Initial release.

[unreleased]: https://github.com/danhorst/after-midnight/compare/v0.2.4...HEAD
[0.2.4]: https://github.com/danhorst/after-midnight/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/danhorst/after-midnight/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/danhorst/after-midnight/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/danhorst/after-midnight/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/danhorst/after-midnight/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/danhorst/after-midnight/releases/tag/v0.1.0
