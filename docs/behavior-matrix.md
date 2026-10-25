# Behavior and test coverage

This guide describes current behavior and where it is tested. Run
`./scripts/check` for the automated suite and `./scripts/smoke` for the installed
bar. Live desktop checks and graphics checks are separate. See
[Contributing](../CONTRIBUTING.md#checks) for prerequisites.

The table describes coverage, not the result of a new test run.

| Area             | Current behavior                                                                                           | Coverage                                                                     |
| ---------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Loading          | Runs inside Omarchy's shell, with a bottom bar on each screen.                                             | Manifest validation, widget lifecycle tests, installed smoke.                |
| Height           | Starts at 44 logical pixels and follows Omarchy's spacing and font scale.                                  | Geometry tests at four scales.                                               |
| Window list      | Shows one task per window across the monitor's workspaces.                                                 | Production model, duplicate-app, and window refresh tests.                   |
| Task order       | Groups by workspace number, then window opening order. Minimized tasks keep their group.                   | Task model and app identity tests.                                           |
| Task updates     | Keeps existing buttons and scroll position when rows change.                                               | Task model and sizing tests.                                                 |
| Task size        | Fits short titles. Shrinks longer buttons before adding scrolling.                                         | Sizing, overflow, and geometry tests.                                        |
| Activation       | Focuses the chosen window and raises it when supported. Keeps the pointer in place.                        | Action and pointer tests; live focus checks on each supported desktop.       |
| Minimize         | Uses the native dock on supported floating workspaces. Uses Tilelane's private workspace otherwise.        | Action, lifecycle, capability, and workspace-mode tests.                     |
| Restore          | Uses a saved origin when present. Other native-dock windows return to their monitor's active workspace.    | Restore and monitor fallback tests; live tiled and floating cycles.          |
| Mode changes     | Moves eligible hidden windows to the dock when their workspace becomes floating.                           | Workspace-mode and migration tests; live mode changes.                       |
| Task menu        | Acts on the selected window and rejects stale targets.                                                     | Action tests and menu policy checks.                                         |
| App identity     | Uses desktop entries, saved overrides, and terminal or web-app matching.                                   | Identity fixtures, including ambiguous matches.                              |
| Pins             | Keeps taskbar and Start pins separate. Taskbar pins stay outside the scrolling task list.                  | Pin, Start order, settings, and overflow tests.                              |
| Launch           | Opens apps normally or floating with Ctrl+Click, Ctrl+Enter in Start, or Open floating.                    | Launch helper, quoting, and bounded client-query tests.                      |
| Workspaces       | Opens the numbered workspace fan on click or after a 200 ms hover.                                         | Workspace state and selection tests; live monitor checks.                    |
| Start search     | Filters the cached app list and respects Omarchy's hidden entries.                                         | Search, selection, and hidden-entry checks.                                  |
| Places           | Shows standard Files locations and follows bookmark names and order.                                       | Parsing and file-watcher tests, including empty files and legacy fallback.   |
| Tray actions     | Supports left, right, and middle clicks plus scrolling.                                                    | Control tests; live D-Bus menus and edge clicks.                             |
| Tray images      | Uses installed theme icons or a generic fallback. Roam gets its icon and unread badge.                     | Source-boundary, native-provider, badge, and graphics tests.                 |
| Tray reveal      | Opens after a 200 ms hover. Caps drawer width and scrolls longer lists.                                    | Geometry tests; live hover and edge checks.                                  |
| Status widgets   | Follows configured order, with the clock last. Opens panels on the relevant screen.                        | Model, lifecycle, manifest, and panel routing tests.                         |
| Panel shortcuts  | Named shortcuts route to enabled panels. Numbered shortcuts count visible panels.                          | Routing tests; live named and numbered shortcuts.                            |
| Start indicators | Uses native indicators. Items without visible artwork take no space.                                       | Native indicator fixtures, sizing, and visibility tests.                     |
| Status icons     | Keeps related symbols at a stable size and fits standalone glyphs to their canvas.                         | Optical glyph and native widget tests; graphics checks at display scales.    |
| Dock tip         | Offers a dock move and auto-hide when the bottom dock overlaps Tilelane. Saves resolved or dismissed tips. | Detector, action, failure, and dismissal tests.                              |
| Translations     | Uses native translations for tips when available; falls back to English.                                   | Missing, broken, native, and live language-change fixtures.                  |
| Appearance       | Uses Omarchy colors and fonts. Defaults to a semi-transparent bar with an opaque Start menu.               | Settings and geometry tests; manual theme and opacity checks.                |
| Input            | Extends clicks to screen edges. Keeps keyboard focus visible without forcing it on pointer clicks.         | Click-area, shared-control, and live edge checks.                            |
| Settings         | Saves pins and preferences in Omarchy's shell settings. Preserves other fields.                            | Restart, external edit, invalid data, legacy import, and inactive-bar tests. |
| Reduced motion   | Stops launch pulses and sets Tilelane's animation durations to zero.                                       | Settings and geometry tests.                                                 |
| Text             | Shows external labels as plain text.                                                                       | Source checks and rendered markup-like bookmark labels.                      |
| Diagnostics      | Omits window titles, command lines, account data, and registry paths.                                      | IPC and sizing checks.                                                       |
| Test crashes     | Fails the suite on new user core dumps during the observation window.                                      | Crash-guard regression tests and isolated provider test.                     |

## Checks that remain open

Battery power comparisons, physical cable hot-plug, and suspend/resume need
hardware testing. Urgent state has fixture coverage. An earlier live terminal
bell test did not produce a compositor urgency event.

There is no complete image comparison for Start and tray scenes in both light
and dark themes. See the [visual guide](visual-parity.md). The
[performance measurements](performance.md) describe an older build.
