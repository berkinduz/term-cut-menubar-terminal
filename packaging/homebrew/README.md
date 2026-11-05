# Peeksh on Homebrew

Peeksh uses the shared [berkinduz/homebrew-tap](https://github.com/berkinduz/homebrew-tap), alongside Slip. Its cask is `Casks/peeksh.rb`, and release binaries stay in [berkinduz/peeksh](https://github.com/berkinduz/peeksh).

The prepared cask installs `Peeksh.app` and links its bundled `peeksh` command. It supports macOS 13+ on Apple silicon and Intel. The checked-in checksum describes the locally verified 0.3.3 DMG; the first Peeksh release and cask publication are still pending.

## Publish or update

1. Publish the app release first. Its workflow generates `peeksh.rb` and `SHA256SUMS` from the same final `Peeksh.dmg`.
2. Download those release assets and verify `shasum -a 256 -c SHA256SUMS`. Use that release's `peeksh.rb` as the shared tap's `Casks/peeksh.rb`; a CI rebuild can differ from the local DMG.
3. Follow the tap's [contribution guide](https://github.com/berkinduz/homebrew-tap/blob/main/CONTRIBUTING.md) for validation and publication. Add Peeksh to its README application table; preserve Slip and existing rename records.

For a final local package, regenerate its cask whenever the DMG bytes change:

```sh
./scripts/generate-cask.sh build/Peeksh.dmg
```

The generator reads the mounted app's version and the DMG's SHA256 into `build/peeksh.rb`.

## Install

Once the app release and its cask are published:

```sh
brew install --cask berkinduz/tap/peeksh
brew upgrade --cask berkinduz/tap/peeksh
```

Homebrew also makes `peeksh .` available in your shell. Local preparation does not publish or install anything.
