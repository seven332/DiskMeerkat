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

## Localization Resources

Keep localizable copy with the target that owns it. Package product copy belongs to `DiskMeerkatApp`; app-shell copy
belongs to the `DiskMeerkat` target. Use stable semantic keys, English default values, and comments that explain the
text to translators. Keep the `DiskMeerkat` brand and machine identifiers unchanged.

The supported runtime localizations are English (`en`) and Simplified Chinese (`zh-Hans`), with English as the
development language. Use Apple's language and script matching through `Bundle`; do not add a parallel locale
resolver. In particular, Chinese (China) preferences select `zh-Hans`, while Traditional Chinese preferences fall
back to English until a `zh-Hant` localization is intentionally added.

The Package catalog at `Packages/DiskMeerkatApp/Localization/Localizable.xcstrings` is the source of truth. Xcode
compiles string catalogs, but command-line Swift Package Manager copies `.xcstrings` without compiling it. The
Package therefore ships generated `.strings` files under
`Packages/DiskMeerkatApp/Sources/DiskMeerkatApp/Resources/<language>.lproj/` so `swift test` and Xcode resolve the
same Package-owned resources.

After changing the Package catalog, regenerate its runtime resources from the repository root:

```sh
xcrun xcstringstool compile \
  Packages/DiskMeerkatApp/Localization/Localizable.xcstrings \
  --output-directory Packages/DiskMeerkatApp/Sources/DiskMeerkatApp/Resources \
  --serialization-format text
```

Commit the catalog and generated runtime resources together. Package localization tests compare their keys and values
for every supported language and verify compatible format placeholders to prevent drift. The App shell uses
`DiskMeerkat/Localizable.xcstrings` directly because its canonical validation builds through Xcode. UI tests must set
`AppleLanguages` and `AppleLocale` independently when language selection or regional formatting is under test.

Release validation requires `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings` in both the app
resources and the embedded `DiskMeerkatApp_DiskMeerkatApp.bundle`. Keep
`.github/scripts/verify-release-app.sh` aligned with the supported localization set.

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
- The working tree is clean and checks relevant to the changed files and behavior pass.

## Release Workflow

Tagged ZIP releases are a temporary distribution path for technical users while Developer ID signing and Apple
notarization are unavailable. Before creating a release, update the app target's three-part `MARKETING_VERSION`, merge
that change to `main`, and create a tag that is exactly `v` followed by the marketing version. For example:

```sh
git switch main
git pull --ff-only
git tag v1.0.0
git push origin v1.0.0
```

The release workflow builds the tagged commit with an ad-hoc identity, requires the tag to match the built app's
`CFBundleShortVersionString`, archives the app with `ditto`, and verifies the extracted bundle before publication. Do
not move or delete the tag while the workflow is running; the publisher refuses a tag that no longer resolves to the
packaged commit. The distributed app is a universal `arm64` and `x86_64` Release build; CI continues to use its
existing `arm64` app-boundary destination.

Build and packaging run with read-only repository contents access and do not use signing secrets. Only the dependent
publisher receives `contents: write`; it performs no checkout and publishes the already verified ZIP. Pull-request jobs
retain read-only access and receive no release credential. The first intentional version tag is the end-to-end check
of the hosted artifact handoff and GitHub Release attachment; local or pull-request validation must not create a test
tag or Release.

## Local Validation

Choose validation according to the changed surface. Run a test suite only when the change affects its code, tests, configuration, dependencies, or covered behavior. Do not run an unrelated suite solely because it exists:

- Documentation-only changes require whitespace, Markdown structure, and link checks, but not Swift tests.
- Swift source changes require formatting.
- Package source, test, manifest, or cross-package changes require tests for every affected package.
- App-target, Xcode project, lifecycle, entitlement, or app-boundary changes require relevant app tests.
- UI tests are required only when the change affects UI tests or behavior that cannot be verified reliably below the UI boundary.

Use `git diff --check` for every change. For documentation, also review the rendered Markdown and verify relative links.

When Swift files change, run the same formatting check as CI:

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

When `Packages/DiskMeerkatApp` sources, tests, or manifest change, run its package tests:

```sh
swift test --package-path Packages/DiskMeerkatApp
```

When a change affects behavior at the real application boundary, run app and UI tests:

```sh
xcodebuild test \
  -project DiskMeerkat.xcodeproj \
  -scheme DiskMeerkat \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM=
```

GitHub CI runs the complete validation suite for every pull request. It also builds the Release app to verify the
macOS 15.0 deployment target, menu-bar-only bundle setting, supported app/package localization resources, and absence
of debug UI-test fixture entry points. Xcode and Package.swift are the authoritative deployment-version declarations;
validation commands must not replace them with the host system version. Local validation should still use the
narrowest credible checks for the actual change. When adding a package, add it to the relevant CI formatting and test
commands as well. The
[V1 Acceptance Matrix](v1-acceptance.md) records the current requirement and built-product evidence.
