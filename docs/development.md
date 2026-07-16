# Development Guide

This document defines the commit convention, code organization, testing strategy, and day-to-day development workflow for DiskMeerkat.

## Core Principles

1. Every commit follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
2. Product code and unit tests belong in `Packages/` by default.
3. The Xcode project is an application shell. It contains only code and configuration that must depend on the app target or Xcode.
4. Prefer unit tests first, integration tests second, and UI tests last. Always use the lowest layer that can reliably verify the behavior.

## Commit Convention

Use the following commit message structure:

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

Common types include:

- `feat`: Add a feature.
- `fix`: Fix a defect.
- `refactor`: Restructure code without changing its external behavior.
- `test`: Add or update tests.
- `docs`: Change documentation only.
- `ci`: Change continuous integration configuration.
- `build`: Change the build system or dependencies.
- `perf`: Improve performance.
- `style`: Change formatting without affecting behavior.
- `chore`: Perform maintenance that does not fit another type.

The optional scope identifies the affected module, such as `app`, `scanner`, or `storage`. Keep the description short and specific, and keep each commit focused on one logical change.

Examples:

```text
feat(app): add disk usage overview
fix(scanner): handle inaccessible directories
refactor(app): move settings into a package
test(storage): cover an empty cache
docs: clarify the development workflow
ci: test all local packages
```

Mark a breaking change with `!` after the type or scope, or add a `BREAKING CHANGE:` footer:

```text
feat(scanner)!: replace the scan result model

BREAKING CHANGE: ScanResult now groups entries by volume.
```

Pull request titles must follow the same Conventional Commit format.

## Package-first Architecture

The repository is organized around local Swift packages:

```text
DiskMeerkat/
├── DiskMeerkat/                 # Xcode application shell
├── DiskMeerkatUITests/          # Tests that require the real application boundary
├── Packages/
│   └── DiskMeerkatApp/          # Main UI and application logic
└── DiskMeerkat.xcodeproj/       # Targets, signing, capabilities, and package wiring
```

The following code belongs in `Packages/` by default:

- Feature views and reusable UI.
- Business logic, state management, and data models.
- File scanning, storage, networking, and other services.
- Unit tests and most integration tests.
- Resources that Swift Package Manager can manage cleanly.

As the application grows, split code into `Packages/<PackageName>/` along cohesive responsibility boundaries. Do not move implementation into the app target merely to avoid creating or extending a package, but also do not create a separate package for every type.

Packages should expose only the APIs required by the app shell or other packages. Keep all other declarations internal. The current app shell assembles its root UI with `ContentView` from the `DiskMeerkatApp` package.

## The Xcode Project Is a Shell

Code belongs in `DiskMeerkat/` or the Xcode project only when it genuinely depends on the application target. Examples include:

- The `@main` entry point and `Scene` lifecycle.
- Package composition and dependency injection.
- App Sandbox settings, entitlements, signing, and target build settings.
- App icons, launch resources, and resources that must belong to the app bundle.
- System capabilities or Xcode integrations that cannot be expressed cleanly from a package.

Do not put business logic, data access, reusable views, or unit-testable behavior in the shell. When the correct location is unclear, start in a package. Treat app-target code as an exception that requires a concrete dependency on the target's identity, bundle, lifecycle, or capabilities.

## Testing Strategy

Keep tests close to the code they cover, and use the lowest layer that can reliably verify the behavior.

### 1. Prefer Unit Tests

Write a unit test whenever the behavior can be verified without launching the real application. Typical subjects include:

- Pure business logic and data transformations.
- Models, parsers, and state transitions.
- Service error handling and boundary inputs.
- Package behavior exposed through a public API.

Place unit tests in the corresponding package under `Tests/<TargetName>Tests/`. Unit tests should be fast and deterministic. Avoid global state, arbitrary delays, and assertions against private implementation details.

### 2. Use Integration Tests for Boundaries

Write an integration test when the behavior depends on multiple real components working together, such as package boundaries, a controlled filesystem, or a persistence implementation. Prefer isolated real resources over mocks of internal modules.

Integration tests should normally live in a Swift package test target. Put them in an Xcode test target only when they must depend on the application target.

### 3. Use UI Tests Last

Use UI tests only for critical behavior that cannot be covered reliably at a lower layer, including:

- Verifying that the app launches and assembles the correct root UI.
- Workflows that require real windows, menus, or system interactions.
- App lifecycle, entitlement, or target-wiring behavior.

Do not use UI tests for pure logic, and do not duplicate details already covered by unit or integration tests. Avoid fixed sleeps. Use explicit, bounded state waits and isolate persistent state such as window restoration.

When fixing a defect, add a regression test at the lowest layer that can reproduce it reliably.

## Adding a Package

Create a new library package under `Packages/`:

```sh
mkdir -p Packages/<PackageName>
cd Packages/<PackageName>
swift package init --type library --name <PackageName>
```

Then:

1. Set a macOS deployment target in `Package.swift` that is compatible with the project.
2. Add unit and integration tests to the package test target.
3. Add the local package product to the Xcode project only when the app shell consumes it.
4. Update `.github/workflows/ci.yml` so CI formats and tests the new package.

## Development Workflow

Start from the latest `main` branch:

```sh
git switch main
git pull --ff-only
git switch -c <type>/<short-description>
```

After implementing and validating the change:

```sh
git add <files>
git commit -m "<type>[optional scope]: <description>"
git push -u origin <branch>
```

Before opening a pull request, confirm that:

- Implementation lives in the appropriate package rather than the app shell.
- Tests follow the unit, integration, then UI priority order.
- Every new package is covered by CI.
- Commit messages and the pull request title follow Conventional Commits.
- The working tree is clean and all formatting and tests pass.

## Local Validation

Run the same formatting check as CI:

```sh
swift format lint \
  --configuration .swift-format \
  --recursive \
  --parallel \
  --strict \
  DiskMeerkat \
  DiskMeerkatUITests \
  Packages/DiskMeerkatApp
```

Run package tests:

```sh
swift test --package-path Packages/DiskMeerkatApp
```

Run app and UI tests:

```sh
local_deployment_target="$(sw_vers -productVersion | cut -d. -f1,2)"

xcodebuild test \
  -project DiskMeerkat.xcodeproj \
  -scheme DiskMeerkat \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "${TMPDIR%/}/DiskMeerkatDerivedData" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM= \
  MACOSX_DEPLOYMENT_TARGET="$local_deployment_target"
```

When adding a package, add it to the relevant formatting and test commands as well.
