# Contributing to Tilelane

Read the [architecture](docs/architecture.md) before changing window actions,
settings, or native widget integration. Update the docs when behavior changes.
Write for the person using the feature. Use familiar words and short sentences.
Explain what they can do before describing how the code works.

## Development setup

Follow the [installation instructions](README.md#install) to load a complete
copy of the plugin. Keep changes in this repository and copy the affected
runtime files into the installed plugin directory. Include `i18n/` with the QML
and scripts. Omarchy's plugin updater follows the repository's default branch,
so use this copy step when testing a development branch.

Omarchy watches installed plugin files. If a changed component stays cached,
run `omarchy restart shell`. The plugin runs inside Omarchy's existing shell.
Do not start another Quickshell process to run the bar.

## Checks

Run these commands from the repository root:

```sh
omarchy plugin validate .
./scripts/check
```

The checks use Qt's QML tools, Quickshell, and Node.js with its built-in modules.
Lua enables the pointer regression tests. No npm packages are required.
Python 3 and access to the systemd journal are required for crash checking.
The suite checks for new core dumps from your user, including helper processes.
It observes the run and waits three seconds after it ends. A crash in an
unrelated app also fails the check and needs investigation. Failure to read or
parse the journal fails the check too.

The native image-provider test additionally uses `dbus-run-session`, `dbus-send`,
and ImageMagick. Its private bus has no activatable service directories. It
asserts that desktop portal activation is unavailable, then checks five benign
images through the real Quickshell provider. To run it separately with crash
checking:

```sh
python3 tests/coredump_guard.py -- bash tests/test-native-provider.sh
```

Use the same wrapper around other standalone rendering or live-test commands
when checking for auxiliary-process crashes.

The tray source tests build a temporary Qt Quick Test provider with `g++`,
`pkg-config`, and Qt development tools (`qt6-base` and `qt6-declarative` on Arch).
This provider records image requests and loads only benign fixtures; it is not
part of the plugin runtime. Keep untrusted-source tests at this request boundary
without constructing oversized or otherwise harmful image fixtures.
Install ShellCheck for shell linting. The script reports skipped checks.
Resolve those skips before calling a run complete.

After installing and selecting Tilelane, run `./scripts/smoke`.
For input or window behavior, also test the affected action in the live bar.
Tray rendering changes need the [shader rendering tests](qml/shaders/README.md).

Changes to Omarchy integration need live checks on both 4.0.6 and 4.5 RC.
The suite tests missing helpers and translation components with fixtures.
Those tests do not replace a run on each desktop version. Check minimize,
restore, focus, pointer position, and any affected native widgets.

For widget integration, `tests/fixtures/dynamic-widget` provides a plugin with
a custom entry point, configurable label, and native panel. Install a copy in
the user plugin directory and enable `local.tilelane-dynamic-test` to check
discovery, settings updates, ordering, and removal in the live bar. Remove the
fixture with `omarchy plugin remove local.tilelane-dynamic-test --yes` afterward.
The automated checks also exercise manifest loading in an isolated, headless
Quickshell process without changing the desktop configuration.
Window-model checks load the production model without a compositor connection.
They cover opening order, state updates, stale close events, and source cleanup.
A separate test sends Hyprland events through local test sockets. It checks
floating-state refreshes, rapid toggles, and windows closed before a refresh.

Documentation-only changes need a link and factual review, not UI tests.

## Reference

- [Behavior and test coverage](docs/behavior-matrix.md)
- [Performance records](docs/performance.md)
- [Appearance and reference images](docs/visual-parity.md)
