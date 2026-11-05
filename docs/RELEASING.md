# Releasing Peeksh

## Prepare locally

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in [Info.plist](../Resources/Info.plist), `TERM_PROGRAM_VERSION` in [ShellConfiguration.swift](../Sources/PeekshCore/ShellConfiguration.swift), and add `docs/releases/v<version>.md`. This checkout prepares 0.3.3/build11.
2. Run `swift test`, then `./scripts/build-app.sh --universal` to create `build/Peeksh.app` for Apple silicon and Intel.
3. Run `./scripts/package-dmg.sh` and `hdiutil verify build/Peeksh.dmg`.
4. Mount the DMG read-only and run `codesign --verify --deep --strict` against its actual Peeksh.app. Confirm bundle version, both architectures, executable peeksh launcher, shell integration resources, and Finder app/Applications layout. Container verification alone does not verify the app signature.
5. After any optional notarization/stapling, run `./scripts/generate-cask.sh build/Peeksh.dmg`. It reads the actual app version and SHA256 from the DMG and creates `build/peeksh.rb`.
6. Generate final checksums with `(cd build && shasum -a 256 Peeksh.dmg > SHA256SUMS)`.

Build/package scripts ad-hoc sign local artifacts. They do not publish a release, create a tap, install software, read credentials, or notarize automatically. `SWIFT_BUILD_SYSTEM=native` may be supplied for a local toolchain that requires the native SwiftPM build system.

## Application identity

The app uses bundle identifier `com.berkinduz.peeksh`, the Peeksh/PeekshCore targets, and the `peeksh` command and shell integration prefix. The only public URL scheme is `peeksh://open`. Storage is scoped to this application identifier; a one-time local handoff can be prepared separately for an existing installation.

## Launcher and Finder service

The new bundle includes `Peeksh.app/Contents/Resources/bin/peeksh`:

```sh
/Applications/Peeksh.app/Contents/Resources/bin/peeksh .
/Applications/Peeksh.app/Contents/Resources/bin/peeksh '/path/with spaces'
/Applications/Peeksh.app/Contents/Resources/bin/peeksh --profile 'Daily work'
/Applications/Peeksh.app/Contents/Resources/bin/peeksh --help
```

The generated Homebrew cask links `peeksh` into the command path. A DMG user may run the bundled executable directly or create a link in an existing command directory:

```sh
ln -s '/Applications/Peeksh.app/Contents/Resources/bin/peeksh' "$HOME/.local/bin/peeksh"
```

The launcher forwards percent-encoded values through `peeksh://open`; the installed app must be registered with macOS. Folders also expose **Open in Peeksh** in Finder Services. The service can be enabled under System Settings → Keyboard → Keyboard Shortcuts → Services if hidden. Directory/profile data never becomes a terminal command.

## Optional Developer ID signing and notarization

`./scripts/sign-release.sh sign` signs `build/Peeksh.app` only when the release owner supplies `PEEKSH_SIGNING_IDENTITY`. `./scripts/sign-release.sh notarize` submits `build/Peeksh.dmg` only with the owner's existing `PEEKSH_NOTARY_PROFILE`. See [release-signing.env.example](../scripts/release-signing.env.example); it contains placeholders only. Do not store secrets in the repository or logs.

After signing the app, package the DMG again. After notarization/stapling, regenerate the cask and checksums from the final bytes. Preserve the signed bundle during Finder-layout preparation; do not change its extension attributes after signing.

## App release and Homebrew tap are separate

The release workflow builds/tests the selected main commit and, when later pushed with the appropriate authorization, publishes:

- `Peeksh.dmg`
- `SHA256SUMS`
- `peeksh.rb`

It uses `docs/releases/v<version>.md` as its release notes and titles the release Peeksh. Local preparation does not publish anything. The shared tap already exists; the first Peeksh release and its cask publication remain pending.

The existing [berkinduz/homebrew-tap](https://github.com/berkinduz/homebrew-tap) hosts one `Casks/<app>.rb` per application. Add `Casks/peeksh.rb` alongside Slip and add Peeksh to the tap README's application table. Preserve other casks and rename records.

Use `peeksh.rb` from the published release and verify its matching `Peeksh.dmg` against that release's `SHA256SUMS`. The [prepared local cask](../packaging/homebrew/Casks/peeksh.rb) describes the local DMG; a CI rebuild can produce different bytes. Follow the tap's [contribution guide](https://github.com/berkinduz/homebrew-tap/blob/main/CONTRIBUTING.md) for Ruby syntax, Homebrew audit/style and installation checks.

The app workflow publishes its own release assets; the tap is updated separately. See the [Homebrew guide](../packaging/homebrew/README.md) for the release-to-tap steps.

After the release and cask are published, users can run:

```sh
brew install --cask berkinduz/tap/peeksh
brew upgrade --cask berkinduz/tap/peeksh
```
