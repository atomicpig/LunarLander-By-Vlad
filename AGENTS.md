# Repository Guidelines

## Project Structure & Module Organization

This repository contains an offline, Romanian-language macOS physics game for Apple Silicon. `Sources/FlightCore/` holds the SI-unit simulation, missions, MIDI parsing, mapping, and input state. Keep this module independent of AppKit, SpriteKit, and CoreMIDI. `Sources/VladPhysics/` contains SwiftUI screens, SpriteKit rendering, the CoreMIDI adapter, and application state. Unit tests live in `Tests/FlightCoreTests/`; application integration tests live in `Tests/GameModelTests/`. Packaging scripts are in `scripts/`; user guides and screenshots belong in `docs/`. Generated `.app`, ZIP, and DMG files stay in ignored `dist/`.

## Build, Test, and Development Commands

- `swift build`: compile the development executable.
- `swift run VladPhysics`: launch from source.
- `bash scripts/test.sh`: run XCTest using full Xcode when available.
- `bash scripts/build-app.sh`: build and ad-hoc sign the arm64 application.
- `bash scripts/package.sh`: produce the application, ZIP, DMG, and SHA-256 checksums.

The deployment target is macOS 13. Use Swift 5.9 or newer. Full Xcode is required for XCTest; the distributed application needs no development tools.

## Coding Style & Naming Conventions

Use four-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for members. Prefer small, explicit value types for physics and controller data. Keep UI state changes on the main thread. Write user-facing text in Romanian with diacritics; use English identifiers and technical comments. No formatter or linter is configured. Avoid external runtime dependencies and network requirements.

## Testing Guidelines

Name tests `testBehaviorUnderCondition` and place them beside the relevant physics or MIDI suite. Verify physical invariants, fuel consumption, landing thresholds, source-independent input release, and profile serialization. All six missions must remain completable through normal flight inputs. There is no coverage percentage requirement. Run tests after behavioral changes and build the app after UI changes. Hardware detection alone does not prove every physical control works; document manual verification separately.

## Commit & Pull Request Guidelines

The project starts without an established commit convention. Use concise imperative subjects, such as `Fix MIDI release after reconnect`. PRs should explain the behavior change, include test results, and link relevant issues. Include screenshots for visible changes and flag compatibility or packaging changes. Never commit signing certificates, credentials, build products, or personal device data.
