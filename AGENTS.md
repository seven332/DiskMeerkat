# Repository Guidelines

Use this file as a quick contributor reference. The [Development Guide](docs/development.md) is authoritative for detailed architecture, testing, commit, and validation policy.

## Project Structure & Module Organization

`DiskMeerkat/` is the thin macOS application shell. Put product UI and logic in `Packages/`; the current module is `Packages/DiskMeerkatApp/Sources/DiskMeerkatApp`. Package tests belong under the matching `Tests/<TargetName>Tests/` directory, while tests requiring the running app live in `DiskMeerkatUITests/`. Keep product and development decisions in `docs/`. See [Package-first Architecture](docs/development.md#package-first-architecture) for ownership rules.

## Build, Test, and Development Commands

- `open DiskMeerkat.xcodeproj` opens the app for local building and running.
- `swift test --package-path Packages/DiskMeerkatApp` runs package tests.
- [Local Validation](docs/development.md#local-validation) maps changed surfaces to canonical checks. Run the checks relevant to the change; documentation-only work does not require Swift or UI tests.

## Coding Style & Naming Conventions

Swift Format enforces four-space indentation and a 120-column limit through `.swift-format`. Use `UpperCamelCase` for types and `lowerCamelCase` for functions, properties, and variables. Name tests by observable behavior, such as `testShowsGreeting`. Keep declarations internal unless another package or the app shell requires the API.

## Testing Guidelines

Use XCTest and follow the [Testing Strategy](docs/development.md#testing-strategy): unit tests first, integration tests for real boundaries second, and UI tests only for behavior requiring the app. Keep tests deterministic, avoid fixed sleeps, and add regression coverage at the lowest reliable layer. No numeric coverage threshold is enforced.

## Commit & Pull Request Guidelines

Follow the [Commit Convention](docs/development.md#commit-convention) for commits and PR titles, for example `feat(monitor): add threshold evaluation`. Keep each PR focused; explain behavior and exclusions, list validation, link relevant issues, and include screenshots for visible UI changes. Submit only with a clean working tree and passing relevant checks.

## Security & Configuration

Never commit credentials, signing identities, personal team IDs, or machine-specific paths. Keep notification permissions, sandbox capabilities, and signing configuration in the app shell rather than package business logic.
