<div align="center">

# term-cut

[![macOS](https://github.com/berkinduz/term-cut-menubar-terminal/actions/workflows/ci.yml/badge.svg)](https://github.com/berkinduz/term-cut-menubar-terminal/actions/workflows/ci.yml)

**Your terminal. One shortcut away.**

A native macOS terminal that lives in your menu bar.
Open a compact panel or a full-width drop-down. Keep your flow.

[Download for Mac](https://github.com/berkinduz/term-cut-menubar-terminal/releases/latest/download/term-cut.dmg) · [Features](#features) · [Build](#build) · [Shortcuts](#shortcuts)

</div>

## Features

- **Two ways in.** A menu bar panel and a drop-down terminal, with customizable global shortcuts.
- **Room to work.** Tabs, resizable split panes, pane focus, and search.
- **Sessions that stay.** Hide the window or switch layouts while commands keep running.
- **Quiet by design.** Native controls, considered colors, gentle transitions, and Liquid Glass on macOS 26+.
- **Make it yours.** Themes, installed monospaced fonts, cursors, sizes, window proportions, scrollback, Meta keys, and startup behavior.
- **A real terminal.** Your login shell, true color, Unicode, and interactive command-line tools. Powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

## Install

[Download the latest release](https://github.com/berkinduz/term-cut-menubar-terminal/releases/latest/download/term-cut.dmg), open the disk image, and drag **term-cut** into **Applications**. Requires macOS 13 or later; supports Apple silicon and Intel.

Releases are ad-hoc signed without Apple notarization. On first launch, macOS may require approval in **System Settings → Privacy & Security**. Building from source is also supported.

## Build

Requires **macOS 13+** and **Xcode 26+** with its command-line tools selected.

```sh
git clone https://github.com/berkinduz/term-cut-menubar-terminal.git
cd term-cut-menubar-terminal
./scripts/build-app.sh
open build/term-cut.app
```

Drag `build/term-cut.app` into Applications. Right-click its menu bar icon for Settings and About. Switch window layouts from the **View** menu or use your global shortcuts. To create an Apple silicon + Intel build, add `--universal`. To package a disk image, run `./scripts/package-dmg.sh`.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Toggle compact panel | `⌃⌥Space` |
| Toggle drop-down | `` ⌃⌥` `` |
| New tab | `⌘T` |
| Split right / down | `⌘D` / `⇧⌘D` |
| Next / previous pane | `⌘]` / `⌘[` |
| Focus / restore pane | `⇧⌘Return` |
| Next / previous tab | `⌃Tab` / `⌃⇧Tab` |
| Find | `⌘F` |
| Close pane / tab | `⌘W` / `⇧⌘W` |
| Hide terminal | `⇧⌘H` |
| Settings | `⌘,` |

Global shortcuts can be changed in Settings. Escape stays available to your shell and editors. Sessions last until you close them or quit the app; they are not restored after quitting. Working-directory inheritance requires shell OSC 7 support.

## Contribute

Open `Package.swift` in Xcode, or work from the command line:

```sh
swift test
./scripts/build-app.sh
```

Small, focused improvements are welcome. [Open an issue](https://github.com/berkinduz/term-cut-menubar-terminal/issues) for bugs or ideas.

Release maintainers: see [Releasing](docs/RELEASING.md).

[MIT License](LICENSE) · Made by [berkinduz](https://github.com/berkinduz) · [Contact](mailto:mberkinduz@gmail.com) · [Buy me a coffee](https://buymeacoffee.com/berkinduz)
