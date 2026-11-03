# Terminal reliability implementation plan

> **For agentic workers:** Use superpowers:executing-plans for sequential implementation in this checkout.

**Goal:** Fix the five remaining issues explicitly authorized in the chat: settings search, reset, legacy preferences, running-process closure, and background-tab zoom loss.

**Architecture:** Keep the existing settings/workspace types. Index visible settings labels for section search, decode preferences independently with per-field defaults, synchronize reset mode through the existing preference callback, and gate destructive session actions centrally in TerminalWorkspace. AppDelegate supplies one native confirmation dialog and guards application termination.

**Tech Stack:** Swift, SwiftUI, AppKit, Darwin process inspection, XCTest.

**Spec:** The user's instruction to fix the remaining findings reported in this chat on 2026-11-03.

## Constraints and review focus

- Preserve the single-row translucent UI, Kanagawa Dragon default, saved valid settings, running sessions during settings changes, and macOS 13 support.
- Search must find visible multiword labels despite case/spacing, and show an explicit empty state.
- Missing, malformed, or unknown preference fields must not discard unrelated valid preferences.
- Restore Defaults must reset both remembered and currently selected mode.
- Closing one pane, a whole tab, or the application must protect foreground commands, shell builtins, and background jobs; cancelling must leave every targeted session unchanged.
- Closing multiple panes should prompt once; idle/ended sessions should close directly.
- Closing a background tab or a nonzoomed sibling must preserve the active zoom.
- Keep the original running release separate from the test preview. Do not publish.

## Steps

- [x] Add regression tests and observe failures for settings compatibility/reset, search labels, and zoom.
- [x] Implement those fixes and run the full suite with `swift test --build-system native`.
- [x] Add real-PTY tests for close cancellation/confirmation, background jobs, and grouped tab closure; observe failures.
- [x] Add the shared close gate, native confirmation, and application quit guard; run the full suite.
- [x] Request a focused review, build the local release/isolated preview, and verify search/reset/confirmation in the app.
- [x] Report verification and any concrete limitation.

## Verification and decisions

- Reproduced missing/malformed preference loss, live/remembered reset mismatch, full-label search failures, and zoom loss before implementing fixes.
- Reproduced real PTY command closure/cancellation failures; covered idle panes in busy tabs, one confirmation per tab, background jobs, shell builtin activity, and no-handler protection.
- Review found two more cases: a nonintegrated shell replaced by `exec /bin/sleep` and search labels containing `/`. Both were reproduced by regression tests, then fixed. No unresolved review finding remains.
- Ruling: an uninspectable or still-starting process is protected conservatively. Idle-only fixtures wait for actual shell output rather than treating a newly forked process group as a ready shell.
- Final suite: 48 tests, 0 failures with `swift test --build-system native`. Default build engine still requires the missing local Metal Toolchain; no system toolchain changes were made.
- Local release application built; isolated preview refreshed. Computer Use confirmed Window mode search, explicit no-results state/Clear Search, Drop-down → Restore Defaults → Compact, Cancel for pane/tab/quit preserving a running `sleep 120`, and Stop and Close removing only the target pane.
- Work stays on `simplify-tabs-kanagawa`; the original release process remains separate. No release published.
