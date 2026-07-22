# DiskMeerkat

<p align="center">
  <img src="docs/design/app-icon.png" alt="DiskMeerkat app icon" width="192">
</p>

[![CI](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml/badge.svg)](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml)

DiskMeerkat is a macOS app for monitoring available disk space and notifying the user before a monitored volume runs too low.

## Project Status

DiskMeerkat V1 is implemented and verified. It monitors the startup volume, reports current status from the menu bar,
and submits one notification per low-space episode when notifications are enabled.

The [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md) are the source of truth for approved V1 behavior, state transitions, product decisions, and acceptance criteria.
The [V1 Acceptance Matrix](docs/v1-acceptance.md) maps every approved requirement and UI interaction to current test,
Release-build, or source evidence.

## Requirements

- macOS 15.0 or later for the application target.
- Xcode with a Swift toolchain compatible with Swift tools version 6.3.

## Releases

Versioned ZIP builds for technical users are attached to
[GitHub Releases](https://github.com/seven332/DiskMeerkat/releases).
These universal (`arm64` and `x86_64`) builds require macOS 15.0 or later. They are ad-hoc signed, not signed with an
Apple Developer ID certificate, and not notarized by Apple.

macOS may block DiskMeerkat before its first launch. If you trust the release and macOS blocks it, try to open the app
once, then open **System Settings > Privacy & Security** and approve DiskMeerkat. This is a temporary distribution
process while Developer ID signing and notarization are unavailable.

## Getting Started

Clone the repository and open the Xcode project:

```sh
git clone https://github.com/seven332/DiskMeerkat.git
cd DiskMeerkat
open DiskMeerkat.xcodeproj
```

Select the `DiskMeerkat` scheme in Xcode, then build or run the app on macOS.

For canonical formatting and test commands, follow [Local Validation](docs/development.md#local-validation).

## Using DiskMeerkat

DiskMeerkat appears as a disk icon in the menu bar without a normal Dock icon. By default, it checks the startup
volume every 15 minutes and treats available space below 20 decimal GB as low. Open Settings to choose another
supported whole-GB threshold or interval, opt in to launch at login, or review notification status.

Notification permission is requested only after you select `Enable Notifications`. `Check Now` runs the same
serialized check used by scheduled and wake-triggered work. After an alert is accepted, DiskMeerkat suppresses
duplicates until a later successful check observes space strictly above the threshold. Closing its windows leaves
monitoring active; choose Quit from the menu to stop it.

## Documentation

- [Development Guide](docs/development.md): commit conventions, architecture, testing strategy, and local validation.
- [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md): approved V1 behavior, notification state machine, product decisions, and acceptance criteria.
- [UI Design](docs/ui-design.md): approved V1 menu-bar experience, settings, status presentation, and notification content.
- [V1 Acceptance Matrix](docs/v1-acceptance.md): requirement-to-test traceability and built-product verification.
- [Repository Guidelines](AGENTS.md): concise instructions for contributors and coding agents.
