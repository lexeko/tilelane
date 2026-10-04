# Tilelane

A bottom taskbar and Start menu for Omarchy.

![Tilelane on Omarchy with the Start menu open](preview.png)

- Each monitor shows windows from all its workspaces, in opening order.
- Minimize and restore keep windows in their tiled or floating mode.
- Short titles use narrower buttons. Longer buttons shrink before scrolling is needed.
- Omarchy themes, configured widgets, and keyboard shortcuts carry over.

## Requirements

Tested on Omarchy 4.0.4 with Hyprland 0.56.2 and Qt 6.11.2.
Tilelane runs inside Omarchy's shell. Places uses Files to open folders.
See the [runtime dependencies](docs/architecture.md#processes-and-commands).

## Install

```sh
omarchy plugin add https://github.com/lexeko/tilelane.git
omarchy bar use io.github.lexeko.tilelane
```

For an installation without Git, see [manual installation](docs/recovery.md#manual-installation).

## Use

- Start pins and taskbar pins are independent. Right-click a taskbar pin to
  reorder it.
- Hold Ctrl while clicking an app launcher or a place to open a floating window.
- Window context menus show the configured Omarchy shortcuts for their actions.

Places follows your bookmarks in Files. Names, order, and bookmark changes
update automatically.

## Configure

Manage status widgets through Omarchy. Start, the workspace switcher, and the
task area have fixed positions. The clock stays at the right when enabled.
See [widget configuration](docs/configuration.md) for layout and settings commands.

Pins and preferences are saved in `~/.config/omarchy/shell.json`.
See [settings and reduced motion](docs/recovery.md#recover-pins-or-settings).

## Update

For the GitHub installation above:

```sh
omarchy plugin update io.github.lexeko.tilelane
omarchy restart shell
```

Updates follow the repository's default branch. For a manual installation,
replace the plugin files with a new complete copy.

## Disable or remove

Return to Omarchy's built-in bar:

```sh
omarchy bar reset
```

Then, to remove Tilelane:

```sh
omarchy plugin remove io.github.lexeko.tilelane
```

Pins and preferences remain available for a later install.
See [recovery and cleanup](docs/recovery.md) for settings or minimized windows.

## Documentation

- [Changelog](CHANGELOG.md)
- [Architecture and dependencies](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)

## License

[MIT](LICENSE). Copyright (c) 2026 Alexey Konoplev.
