# Changelog

## Unreleased

- Support Omarchy 4.5 RC while keeping compatibility with 4.0.6. Use native
  translations for tips when available, with English as the fallback.
- Restore windows minimized through Omarchy's titlebar or dock. On floating
  workspaces, let the dock and Tilelane restore the same minimized windows.
- Keep hidden windows available in the dock when their workspace switches
  from tiled to floating mode.
- Fix task activation and restore choosing the wrong window on older Omarchy.
  Keep the pointer in place when minimizing to the newer dock.
- Group tasks by workspace number, then by window opening order.
- Make the taskbar semi-transparent by default. Double-click empty space to
  toggle opacity. Keep saved choices and the opaque Start menu.
- Add a Dock tip when Omarchy's dock overlaps the taskbar. Choose another edge
  to move the dock and enable auto-hide. Remember resolved or dismissed tips.
- Use Omarchy's native Start indicators and hide those with no visible content.
  Keep icon sizes consistent across the tested Omarchy versions.
- Improve weather, Dropbox, and other status icon sizes.
- Show Roam's installed tray icon and a red badge for unread messages.

## 0.2.2

- Restrict application tray images to installed icon themes, ignoring
  application-provided paths and opaque image handles before image loading.
- Use a generic icon for private-file and pixmap-only artwork while preserving
  tray menus, clicks, scrolling, and tooltips.
- Add regression coverage for tray image sources and retain symbolic colors,
  colored badges, and icon sizes.

## 0.2.1

- Tighten tray and status control spacing while preserving icon sizes and
  clear gaps between groups.
- Share fixed-font rendering across panel, battery, and standard native status
  icons, keeping related symbols at a stable scale as their state changes.
- Fit weather glyphs within a consistent maximum extent and bring the update
  indicator into the shared status renderer.
- Verify compatibility with Omarchy 4.0.5 and Qt 6.12.

## 0.2.0

- Size task buttons to their titles, keeping short titles compact. When space
  runs out, longer buttons shrink to 105 scaled pixels before scrolling begins.
- Scroll newly opened windows' task buttons fully into view.
- Keep Start's indicator icons visible under opaque hover highlights.
- Balance the Start button's left and right padding.
- Shorten the workspace hint to "Move to monitor".
- Add task-sizing diagnostics that omit window titles.
- Remove Python from the test suite. The test drivers use Node.js built-in modules.
- Simplify the README and move detailed setup guidance into linked guides.

## 0.1.1

- Display bookmark names and other Tilelane labels as plain text, preventing
  embedded markup from changing their appearance or loading inline images.

## 0.1.0

First release.

- A bottom taskbar on each monitor, inside Omarchy's existing shell process.
- One task per window, kept in opening order across focus and minimize changes.
- Minimize and restore that preserve tiled or floating mode and pointer position.
- Separate taskbar and Start pins, app search, and Files bookmarks in Places.
- Desktop-entry icons, with terminal-app and web-app matching.
- Normal and floating launches for apps and folders.
- Window context menus with Omarchy's shortcut hints.
- Per-monitor workspace switching, tray icons, and configured Omarchy widgets.
- Native panel shortcuts, with panels opening on the relevant monitor.
- Dynamic widget loading, stable panel state during reordering, and cleanup on reload.
- Start dismissal on outside clicks, including clicks on another monitor.
- Omarchy themes, menu rounding, and shared hover and open-panel styling.
- Screen-edge click areas, delayed hover drawers, and fading task overflow.
- Keyboard navigation, accessible names, and reduced motion.
- Pins and preferences stored in Omarchy's shell settings.
