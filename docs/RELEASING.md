# Releasing

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in [Info.plist](../Resources/Info.plist), and `TERM_PROGRAM_VERSION` in [ShellConfiguration.swift](../Sources/TermCutCore/ShellConfiguration.swift).
2. Add release notes at `docs/releases/v<version>.md`.
3. Run `swift test` and `./scripts/build-app.sh --universal`.
4. Push the changes to `main`.

After macOS CI succeeds for the current `main` commit, the Release workflow tests and builds the application, creates its version tag, and publishes the DMG and SHA-256 checksum. The disk image contains the application and an Applications shortcut for drag-and-drop installation. Existing releases remain unchanged; bump the version to publish an update.

The build is ad-hoc signed. Developer ID signing and notarization are separate distribution steps and are not configured in this repository.

To select a SwiftPM build engine explicitly, set `SWIFT_BUILD_SYSTEM` when running the build script, for example `SWIFT_BUILD_SYSTEM=native ./scripts/build-app.sh --universal`.

The disk image's Finder window uses `Resources/DMG/FinderLayout.dsstore` to show the application and Applications shortcut side by side. To regenerate this metadata, install the optional Python package `ds-store` in a virtual environment and run `scripts/create-dmg-layout.py`; normal packaging does not require Python dependencies.
