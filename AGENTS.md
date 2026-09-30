# Repository Guidelines

## Project Structure & Module Organization

This is an offline, Romanian-language Lunar Lander game for Apple Silicon. `Sources/FlightCore/` contains the SI-unit simulation, lunar terrain, landing contact, engine response, MIDI parsing, and controller profiles. Keep this module independent of AppKit, SpriteKit, and CoreMIDI. `Sources/VladLander/` contains SwiftUI dialogs, AppKit/CoreGraphics rendering, audio, the CoreMIDI adapter, and application state. Core tests live in `Tests/FlightCoreTests/`; application integration tests live in `Tests/LanderTests/`. Packaging scripts belong in `scripts/`, and user guides and screenshots in `docs/`. Generated bundles and archives stay in ignored `dist/`.

## Build, Test, and Development Commands

- `swift build`: compile the development executable.
- `swift run VladLander`: launch from source.
- `bash scripts/test.sh`: run all XCTest suites with full Xcode.
- `bash scripts/build-app.sh`: build and ad-hoc sign the arm64 app.
- `bash scripts/package.sh`: generate the app, ZIP, DMG, and checksums.

The deployment target is macOS 13; use Swift 5.9 or newer. XCTest requires full Xcode. Distributed builds require no development tools. Set `VLAD_VERSION` when packaging a new release.

## Coding Style & Naming Conventions

Use four-space indentation, `UpperCamelCase` types, and `lowerCamelCase` members. Prefer explicit value types for physics and input. Change UI state on the main thread. Write interface text in Romanian with diacritics and identifiers in English. No formatter or linter is configured. Avoid external runtime dependencies and network requirements.

## Testing Guidelines

Name tests `testBehaviorUnderCondition`. Verify physical invariants, fuel accounting, finite pad pulses, landing limits, swept collisions, profile migration, and input clearing. All three platforms must remain reachable through normal flight controls. Compare trajectories across frame rates; keep live readouts out of SwiftUI layout. Verify the clock advances in mouse-tracking mode. There is no coverage percentage requirement. Run tests after behavioral changes and build after UI changes. Record physical hardware checks separately from replayed MIDI tests.

## Commit & Pull Request Guidelines

History uses concise imperative subjects, such as `Build Vlad physics game with granular AKAI flight controls`. Follow that style. PRs should describe behavior changes, relevant issues, and validation. Include screenshots for visible changes and flag migration or packaging changes. Never commit credentials, certificates, personal controller profiles, or build products.
