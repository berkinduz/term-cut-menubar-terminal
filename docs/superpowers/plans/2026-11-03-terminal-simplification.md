# Terminal simplification implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan in the current session. Steps use checkbox syntax for tracking.

**Goal:** Replace the branded, two-row terminal header with a single row of tabs and controls; add Kanagawa Dragon as the default theme; investigate reliability issues.

**Architecture:** Keep the existing SwiftUI/AppKit views and SwiftTerm sessions. Tabs remain horizontally scrollable alongside fixed trailing controls. Read the palette from the user's installed Kanagawa VS Code theme; retain previously saved theme choices.

**Tech Stack:** Swift, SwiftUI, AppKit, SwiftTerm, XCTest.

**Spec:** User's 2026-11-03 request and attached application screenshot in this chat.

## Global constraints

- macOS 13+, no additional dependencies.
- Show the tab strip even for one tab; remove the terminal icon/name branding from the terminal header.
- Keep tabs and right-side controls on one line in both window modes.
- Use the installed Kanagawa Dragon terminal background, foreground, selection, and 16 ANSI colors.
- Preserve running sessions, saved preferences, keyboard actions, tab renaming, window dragging, and pane layouts.
- Follow-up: use native background blur for window bars instead of opaque black bars or a prominent control capsule. Keep terminal content opaque and honor Reduce Transparency.
- Work in the existing checkout on a feature branch. Do not publish a release.

## Review focus

- Many tabs and long titles at the minimum compact width: trailing controls must stay reachable.
- One tab: tab title and context menu remain reachable.
- Switching/closing tabs containing splits: active pane must belong to the active tab.
- Applying a theme: existing terminal process remains alive; saved theme choices survive reload.
- Settings search and reset: reproduce findings and distinguish confirmed problems from untested risks.

### Task 1: Default theme and compact tab toolbar

**Files:** `Sources/TermCut/Preferences.swift`, `Sources/TermCut/TerminalSession.swift`, `Sources/TermCut/TerminalView.swift`, `Tests/TermCutTests/ThemeTests.swift`, `THIRD_PARTY_NOTICES.md`, `README.md`.

**Interfaces:** Existing `TerminalTheme`, `AppPreferences`, `TerminalSession.apply`, and `TerminalWindowView`.

- [x] Add failing tests for the default theme and live terminal palette, with saved-theme compatibility coverage.
- [x] Run `swift test --build-system native --filter ThemeTests`; verify the expected failures.
- [x] Add the palette, default, selection color, and attribution. Merge the header and tab bar, preserving horizontal scrolling and a draggable gap.
- [x] Run the full test suite.
- [x] Build an application with the available native build engine and inspect it using Computer Use at compact and drop-down widths, with one/many tabs and long names.

### Task 2: Tab reliability and focused investigation

**Files:** `Sources/TermCut/TerminalSession.swift`, `Sources/TermCut/TerminalView.swift`, `Tests/TermCutTests/TerminalIntegrationTests.swift`, and a concise findings document if needed.

**Interfaces:** `TerminalWorkspace.select`, `selectTab`, `close`, `restartActive`, and `TerminalHost`.

- [x] Reproduce last-active-pane loss and focus timing; write failing tests for confirmed defects related to the tab changes.
- [x] Apply narrow fixes and run the full suite.
- [x] Investigate settings search/reset, close behavior, cwd handling, and split layout; report unrelated findings without expanding the UI scope.
- [x] Review the final diff, verify the built app, and report tests, remaining issues, and the local build path.

## Progress

- Baseline: clean checkout at release v0.1.4; 20 tests passed in the preceding audit. Default build engine is blocked by the missing local Metal Toolchain; `--build-system native` works.
- Design: the request fully specifies the small visual change; use the existing architecture and installed theme, with no separate design approval cycle.
- Theme and focus tests: expected failures reproduced before implementation; all 28 tests passed after implementation.
- Investigation: isolated probes confirmed Restore Defaults retains lastWindowMode, and a missing saved preference key discards the entire saved preferences object. Settings search and unguarded process closure remain confirmed findings from the initial audit.
- Review: one fresh reviewer found no introduced defect; deferred pre-existing minor: closing a background tab clears the active tab's pane zoom.
- Visual test: rapidly opened tabs changed width when shell titles arrived and clipped the selected tab. Keep each tab's title area at a stable width so shell title changes cannot move the selected tab out of view.
- Visual test: shrinking the window also needs to reveal the active tab again; observe the tab viewport width and scroll the active tab into view after resizing. Mark the active tab selected for accessibility.
- Final verification: 28/28 tests passed; release app built for this Mac and signed locally. Computer Use verified one/many tabs, a long renamed title, 520 pt and 760 pt compact windows, and drop-down mode. The selected tab remained visible after resizing. A separate preview bundle keeps the original running application and its settings separate.
- Follow-up material review: no actionable new regressions found. Changes remain local on `simplify-tabs-kanagawa`; no release was published.
- Subsequent authorization: all remaining findings, including the deferred zoom issue, were fixed under `2026-11-03-terminal-reliability.md`; the full suite now has 48 passing tests.
- Further visual refinement requested: reduce the toolbar from 42 pt to 34 pt, tab padding/highlight and icon weight; retain existing control hit areas and slightly enlarge tab-close targets. Reduce the material opacity to 0.8 and theme tint to 0.06, with primary control colors for readability. Native opaque accessibility fallback remains. All 48 tests passed; refreshed/signed the local preview and visually verified the two-tab toolbar and clickable menu.
