#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
omarchy_root="${OMARCHY_PATH:-/usr/share/omarchy}"
if [[ -z "${TILELANE_ICON_LIBRARY:-}" ]]; then
  for mode in native missing; do
    TILELANE_ICON_LIBRARY="$mode" bash "$0"
  done
  exit
fi
test_dir=$(mktemp -d)
shell_pid=""
icon_dir="$test_dir/data/icons/hicolor/scalable/apps/space # dir"
cleanup() {
  local status=$?
  if [[ -f "$test_dir/shell.pid" ]]; then
    kill "$(cat "$test_dir/shell.pid")" 2>/dev/null || true
  fi
  if [[ -n "$shell_pid" ]]; then
    kill "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
  fi
  if ((status != 0)); then
    cat "$test_dir/runtime.log" >&2 || true
  fi
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/services" "$test_dir/data/applications" "$icon_dir" "$test_dir/home"
cp -r "$repo_dir/qml" "$repo_dir/scripts" "$test_dir/"
cp "$repo_dir/tests/quickshell/application-icons.qml" "$test_dir/shell.qml"
# Task menus need a compositor; keep the production buttons and image bindings.
cat > "$test_dir/qml/components/TaskContextMenu.qml" <<'QML'
import QtQuick
Item {
    property var anchorItem
    property var bar
    property var actions
    property var applicationCatalog
    property var pinnedApplications
    property string address: ""
    property string title: ""
    property string desktopId: ""
    property bool open: false
    property bool launcherOnly: false
    property bool minimized: false
    property bool fullscreen: false
    property bool maximized: false
    property bool floating: false
}
QML
for file in AppLibrary.qml AppSearch.js PluginAppLibraryApi.qml; do
  cp "$omarchy_root/shell/services/$file" "$test_dir/services/"
done
for module in Commons Ui; do
  ln -s "$omarchy_root/shell/$module" "$test_dir/$module"
done
# Prevent auxiliary desktop service activation in the isolated render process.
cat > "$test_dir/bus.conf" <<'XML'
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
XML
cat > "$test_dir/data/icons/hicolor/index.theme" <<'THEME'
[Icon Theme]
Name=Hicolor
Directories=scalable/apps
[scalable/apps]
Size=32
Type=Scalable
MinSize=1
MaxSize=256
Context=Applications
THEME

# The inner shell records the process to stop before its D-Bus wrapper.
# shellcheck disable=SC2016
env TILELANE_ICON_TEST_DIR="$test_dir" HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/data" XDG_DATA_DIRS="$test_dir/data" \
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_SYSTEM_ICON_THEME=hicolor \
  dbus-run-session --config-file="$test_dir/bus.conf" -- \
  sh -c 'echo "$$" > "$TILELANE_ICON_TEST_DIR/shell.pid"; exec quickshell --path "$TILELANE_ICON_TEST_DIR" --no-color' \
  > "$test_dir/runtime.log" 2>&1 &
shell_pid=$!
ipc() {
  quickshell ipc --path "$test_dir" call test.icons "$@"
}
await_state() {
  local query="$1" state=""
  for ((attempt = 0; attempt < 100; attempt++)); do
    state=$(ipc state 2>/dev/null) || true
    if jq -e "$query" <<< "$state" >/dev/null 2>&1; then
      return
    fi
    sleep 0.05
  done
  printf 'Application icons failed: %s\n%s\n' "$query" "$state" >&2
  return 1
}
install_icon() {
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path fill="#00ff00" d="M0 0h32v32H0z"/></svg>' \
    > "$icon_dir/tilelane-late-icon.svg"
}

await_state '.listed == false'
cat > "$test_dir/data/applications/tilelane-late-icon.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=tilelane-late-icon
Exec=true
Icon=tilelane-late-icon
DESKTOP
await_state '.listed and (.indexed | not)'
# Let the host's 750ms app-change scan finish before the package places its icon.
sleep 1.2
install_icon
await_state '.indexed and .taskReady == 1 and .pinReady == 1'
ipc openMenu
await_state '.menuReady == 1'

# A much later icon (after install retries stop) must recover on opening Start.
rm "$icon_dir/tilelane-late-icon.svg"
ipc openMenu
await_state '(.indexed | not)'
sleep 4
install_icon
ipc openMenu
await_state '.indexed and .menuReady == 1 and .taskReady == 1 and .pinReady == 1'
await_state '.refreshesRemaining == 0'
requests=$(ipc state | jq '.refreshRequests')
sleep 1.2
await_state ".refreshRequests == $requests"
ipc useLibrary missing
ipc useLibrary legacy
await_state '.taskReady == 1 and .pinReady == 1'
# Start's real PanelWindow needs a compositor; verify its opening hook here.
rg -Uq 'onOpenChanged: \{[^}]*applicationCatalog\.refreshIcons\(\)' "$repo_dir/qml/components/StartMenu.qml"
if rg -n 'TypeError|ReferenceError|ERROR|Failed to load' "$test_dir/runtime.log"; then
  exit 1
fi
printf 'Application icons (%s): late install and Start refresh update menu, task and pin images\n' "$TILELANE_ICON_LIBRARY"
