# Peeksh on Homebrew

Peeksh uses the shared [berkinduz/tap](https://github.com/berkinduz/tap), alongside Slip. Its cask is `Casks/peeksh.rb`, and release binaries stay in [berkinduz/peeksh](https://github.com/berkinduz/peeksh).

The cask installs `Peeksh.app` and links its bundled `peeksh` command. It supports macOS 13+ on Apple silicon and Intel. The checked-in cask matches the published 0.3.3 DMG.

## Publish or update

1. Publish the app release first. Its workflow generates `peeksh.rb` and `SHA256SUMS` from the same final `Peeksh.dmg`.
2. Download those release assets and verify `shasum -a 256 -c SHA256SUMS`. Use that release's `peeksh.rb` as the shared tap's `Casks/peeksh.rb`; a CI rebuild can differ from the local DMG.
3. Validate Ruby syntax, Homebrew audit/style and installation with the [cask cookbook](https://docs.brew.sh/Cask-Cookbook), then publish `Casks/peeksh.rb` in the shared tap. Preserve the other applications' casks.

For a final local package, regenerate its cask whenever the DMG bytes change:

```sh
./scripts/generate-cask.sh build/Peeksh.dmg
```

The generator reads the mounted app's version and the DMG's SHA256 into `build/peeksh.rb`.

## Install

The repository is named `tap`, so supply its URL explicitly when adding it:

```sh
brew tap berkinduz/tap https://github.com/berkinduz/tap
brew install --cask berkinduz/tap/peeksh
brew upgrade --cask berkinduz/tap/peeksh
```

Homebrew also makes `peeksh .` available in your shell. Local preparation does not publish or install anything.
