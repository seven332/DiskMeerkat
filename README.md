# DiskMeerkat

[![CI](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml/badge.svg)](https://github.com/seven332/DiskMeerkat/actions/workflows/ci.yml)

DiskMeerkat is a macOS app for monitoring available disk space and notifying the user before a monitored volume runs too low.

> [!NOTE]
> DiskMeerkat is in early development. The repository currently contains the application shell, a package-first project structure, tests, CI, and product requirements. Disk-space monitoring is planned but not yet implemented.

## Planned Behavior

The initial monitoring feature is designed to:

- Check available disk space at a user-configurable interval.
- Let the user configure the low-space threshold.
- Send a notification when available space falls below the threshold.
- Send only one notification while space remains low.
- Rearm notifications only after a later check observes space above the threshold.
- Preserve settings and notification-suppression state across app restarts.

The detailed state transitions, edge cases, acceptance criteria, and open product decisions are documented in [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md).

## Project Structure

DiskMeerkat uses a package-first architecture. Most product code and tests belong in local Swift packages, while the Xcode application target remains a thin shell for lifecycle and platform-specific integration.

```text
DiskMeerkat/
├── DiskMeerkat/                 # Xcode application shell
├── DiskMeerkatUITests/          # UI tests requiring the app boundary
├── Packages/
│   └── DiskMeerkatApp/          # Main UI, product logic, and package tests
├── docs/                        # Development and product documentation
└── DiskMeerkat.xcodeproj/
```

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

## Validation

Run package tests from the repository root:

```sh
swift test --package-path Packages/DiskMeerkatApp
```

Formatting, app tests, and UI tests use the same commands as CI. See the [Development Guide](docs/development.md#local-validation) for the complete local validation workflow.

## Documentation

- [Development Guide](docs/development.md): commit conventions, architecture, testing strategy, and local validation.
- [Disk Space Monitoring Requirements](docs/disk-space-monitoring.md): planned behavior, notification state machine, acceptance criteria, and open decisions.

## Development Principles

- Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) for commits and pull request titles.
- Put product code in `Packages/` by default.
- Keep the Xcode project as a thin application shell.
- Prefer unit tests, then integration tests, and use UI tests only when lower-level tests cannot verify the behavior.

Read the [Development Guide](docs/development.md) before making changes.
