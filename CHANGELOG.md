# Changelog

## Unreleased

- Fixed Start dismissal when clicking outside on another monitor.
- Displayed the tray, status widgets, and clock on every monitor.
- Loaded configured Omarchy widgets dynamically in layout order, including third-party widgets.
- Shared status-control focus, hover, and panel underline behavior across native controls and tray items.
- Preserved open widget panels when their settings or order change.
- Added a bottom taskbar inside the existing Omarchy shell process.
- Added one task per window, pins, Start search, Files places, and a workspace fan.
- Added desktop-entry icons and bounded terminal-app and web-app matching.
- Added normal and floating launches through Omarchy's app scope.
- Added direct tray menus, native Omarchy panels, and the clock.
- Kept Start pins separate from taskbar pins.
- Stored pins and preferences in Omarchy's shell settings.
- Kept pinned apps fixed while running tasks scroll.
- Added matching overflow controls and wider fades for clipped tasks.
- Changed the workspace button to a smaller numbered icon with opaque fan blades.
- Matched Start and tray menu rounding and dividers to Omarchy styling.
- Replaced open-state frames on tray controls and the clock with underlines.
- Fixed tray mouse-button routing and outside-click menu dismissal.
- Added a 200 ms tray hover delay.
- Fixed opening-order tracking and preserved task rows and scroll position.
- Fixed minimize recovery so tiled and floating windows retain their mode.
- Kept the pointer in place when activating tasks.
- Extended taskbar click areas to the bottom edge. Start and clock also reach their outer screen edges.
- Restored standard named and numbered Omarchy panel shortcuts.
- Added keyboard actions, accessible names, reduced motion, and regression tests.
