# Releasing

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in [Info.plist](../Resources/Info.plist), and `TERM_PROGRAM_VERSION` in [ShellConfiguration.swift](../Sources/TermCutCore/ShellConfiguration.swift).
2. Add release notes at `docs/releases/v<version>.md`.
3. Run `swift test` and `./scripts/build-app.sh --universal`.
4. Push the changes to `main`.

After macOS CI succeeds for the current `main` commit, the Release workflow tests and builds the application, creates its version tag, and publishes the DMG, application ZIP, and SHA-256 checksums. Existing releases remain unchanged; bump the version to publish an update.

The build is ad-hoc signed. Developer ID signing and notarization are separate distribution steps and are not configured in this repository.
