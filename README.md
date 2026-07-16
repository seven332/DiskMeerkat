# DiskMeerkat

[![CI](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml/badge.svg)](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml)

DiskMeerkat is a macOS app for monitoring available disk space and notifying the user before a monitored volume runs too low.

## Project Status

> [!NOTE]
> DiskMeerkat is in early development. Disk-space monitoring is specified but not yet implemented.

The [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md) are the source of truth for approved V1 behavior, state transitions, product decisions, and acceptance criteria.

## Requirements

- macOS 26.5 or later for the application target.
- Xcode with a Swift toolchain compatible with Swift tools version 6.3.

## Getting Started

Clone the repository and open the Xcode project:

```sh
git clone https://github.com/seven332/DiskMeerkat.git
cd DiskMeerkat
open DiskMeerkat.xcodeproj
```

Select the `DiskMeerkat` scheme in Xcode, then build or run the app on macOS.

For canonical formatting and test commands, follow [Local Validation](docs/development.md#local-validation).

## Documentation

- [Development Guide](docs/development.md): commit conventions, architecture, testing strategy, and local validation.
- [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md): approved V1 behavior, notification state machine, product decisions, and acceptance criteria.
- [UI Design](docs/ui-design.md): approved V1 menu-bar experience, settings, status presentation, and notification content.
- [Repository Guidelines](AGENTS.md): concise instructions for contributors and coding agents.
