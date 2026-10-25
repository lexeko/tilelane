# Configure Tilelane

Tilelane uses the widgets and settings configured through Omarchy. Changes
apply without restarting the shell.

## Appearance

The taskbar is semi-transparent by default. Double-click unused taskbar space
to switch to an opaque background or back. Tilelane saves the choice and keeps
any choice you made before updating. Start stays opaque in both modes.

The setting is `bar.tilelaneTranslucent` in `shell.json`.

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
Start uses Omarchy's native indicators. Indicators with no visible content
take no space.

Change settings through Omarchy. For example, use a 12-hour clock:

```sh
omarchy bar set omarchy.clock format 'h:mm AP'
```

Third-party widgets retain their own controls and may use different styling.

## Application tray

Application tray icons appear in the tray drawer. Tilelane uses installed theme
icons. Apps that supply only their own image files or raw images show a generic
app icon. Their tooltips, menus, clicks, and scrolling still work.

Roam uses its installed icon with a red badge when messages are unread.
Other changes to Roam's tray artwork are not shown.

## Dock overlap

On Omarchy versions with a dock, a Dock tip can appear in the taskbar. It shows
when an always-visible dock shares the bottom edge with Tilelane on a floating
workspace, outside fullscreen mode.

Choose Left, Top, or Right to move the dock to that edge and turn on auto-hide.
A successful choice also dismisses the tip. The dock changes only when you
choose an action. If an action fails, the card shows an error so you can retry.

"Later" closes the card but leaves the Dock button available.
"Don't show again" hides this tip and saves that choice. Other tips can still
appear. To bring a dismissed tip back, see [saved settings](recovery.md#recover-pins-or-settings).

## Saved settings

Pins, identity overrides, tip dismissals, and reduced motion are stored in Omarchy's
`shell.json`. See [settings and reduced motion](recovery.md#recover-pins-or-settings)
for the fields and commands.
