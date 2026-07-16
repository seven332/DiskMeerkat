# Repository Guidelines

## Project Structure & Module Organization

`DiskMeerkat/` is the thin macOS application shell. Keep only the `@main` entry point, app lifecycle, assets, entitlements, and target-specific wiring there. Put product UI and logic in local packages under `Packages/`; the current module is `Packages/DiskMeerkatApp/Sources/DiskMeerkatApp`. Package unit and integration tests belong in the matching `Tests/<TargetName>Tests/` directory. Tests that require the running application live in `DiskMeerkatUITests/`. Product and development decisions are documented in `docs/`, and CI is defined in `.github/workflows/ci.yml`.

## Build, Test, and Development Commands

- `open DiskMeerkat.xcodeproj` opens the app for local building and running.
- `swift test --package-path Packages/DiskMeerkatApp` runs package tests.
- `swift format lint --configuration .swift-format --recursive --parallel --strict DiskMeerkat DiskMeerkatUITests Packages/DiskMeerkatApp` checks all Swift formatting exactly as CI does.
- `xcodebuild test -project DiskMeerkat.xcodeproj -scheme DiskMeerkat -destination 'platform=macOS,arch=arm64'` runs app and UI tests. Use the signing and deployment-target overrides documented in `docs/development.md` when needed.

## Coding Style & Naming Conventions

Use Swift Format with four-space indentation and a 120-column limit. Prefer `UpperCamelCase` for types and `lowerCamelCase` for functions, properties, and variables. Name tests by observable behavior, for example `testShowsGreeting`. Keep public package APIs minimal; declarations should remain internal unless another package or the app shell needs them.

## Testing Guidelines

Use XCTest. Prefer fast, deterministic unit tests, then integration tests for real component boundaries, and UI tests only for behavior requiring the application boundary. Avoid fixed sleeps, global state, and assertions against private implementation details. Add regression coverage at the lowest reliable layer. No numeric coverage threshold is currently enforced.

## Commit & Pull Request Guidelines

Follow Conventional Commits 1.0.0: `<type>[optional scope]: <description>`, such as `feat(monitor): add threshold evaluation` or `docs: clarify setup`. Pull request titles follow the same format. Keep each PR focused, explain behavior and exclusions, list validation performed, link relevant issues, and include screenshots for visible UI changes. Before submission, ensure formatting and relevant tests pass and the working tree is clean.

## Security & Configuration

Never commit credentials, signing identities, personal team IDs, or machine-specific paths. Keep notification permissions, sandbox capabilities, and signing configuration in the app shell rather than package business logic.
