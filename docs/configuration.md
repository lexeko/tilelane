# Widget configuration

Tilelane uses the widgets and settings configured through Omarchy. Changes
apply without restarting the shell.

## Layout

Start, the workspace switcher, pins, and tasks have fixed positions.
Configured status widgets appear to their right. The clock comes last when
enabled.

Omarchy's layout sections map to Tilelane's status area in this order:

1. Widgets from `left`, followed by widgets from `right`.
2. Widgets from `center`.
3. The clock, regardless of its configured section.

Order within each group follows your configuration. Tilelane supplies its own
menu and workspace controls, so it skips Omarchy's menu and workspace widgets.
Start contains the indicators instead of placing them in the status area.

On Omarchy versions with a dock, Tilelane may show a Dock tip in the taskbar
when the always-visible dock and Tilelane share the bottom edge of a floating
workspace. Choose Left, Top, or Right to move the dock there and turn on
auto-hide with one click. A successful choice also dismisses this tip
permanently. Tilelane changes the dock only when you choose one of these
actions. "Later" hides the tip for this shell session. "Don't show again"
stores a dismissal for this tip only; future tips remain available.

For example, move Volume before Bluetooth:

```sh
omarchy bar move omarchy.audio --section right --before omarchy.bluetooth
```

This changes widget order within the status area. The bar stays at the bottom
of each screen.

## Widget settings

Use `omarchy plugin enable` and `omarchy plugin disable` to add or remove
optional widgets. Some configured widgets appear only when needed, such as
Power when a battery is present or Updates when updates are available.
Application tray icons appear in the tray drawer.
Tilelane uses icons from the installed icon theme. Apps that supply only private
image files or raw pixmaps show a generic application icon; their tooltips,
menus, clicks, and scrolling still work.
Roam uses its installed theme icon when its tray service supplies a pixmap
without an icon name. Tilelane reads the unread dot from Roam's tray pixmap
outside the shell and draws a red badge over that icon when messages are unread.
Other changes in Roam's tray artwork are not displayed.

Change settings through Omarchy. For example, use a 12-hour clock:

```sh
omarchy bar set omarchy.clock format 'h:mm AP'
```

Third-party widgets retain their own controls and may use different styling.

## Tilelane settings

Pins, identity overrides, tip dismissals, and reduced motion are stored in Omarchy's
`shell.json`. See [settings and reduced motion](recovery.md#recover-pins-or-settings)
for the fields and commands.
