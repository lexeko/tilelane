#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir=$(mktemp -d)
cleanup() {
  local status=$?
  if ((status != 0)) && [[ -f "$test_dir/runtime.log" ]]; then
    cat "$test_dir/runtime.log" >&2
  fi
  rm -r -- "$test_dir"
}
trap cleanup EXIT

# No includes or service directories: desktop services cannot autoactivate.
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
mkdir -p "$test_dir/qml/components" "$test_dir/data/icons/tilelane-test/32x32/apps" "$test_dir/external"
cp "$repo_dir/qml/components/TrayIcon.qml" "$test_dir/qml/components/"
cp "$repo_dir/qml/TrayIconSource.js" "$test_dir/qml/"
cp -r "$repo_dir/scripts" "$test_dir/"
cp -r "$repo_dir/qml/shaders" "$test_dir/qml/"
cat > "$test_dir/data/icons/tilelane-test/index.theme" <<'THEME'
[Icon Theme]
Name=Tilelane Test
Directories=32x32/apps
[32x32/apps]
Size=32
Type=Fixed
Context=Applications
THEME
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path fill="#00ff00" d="M0 0h32v32H0z"/></svg>' > "$test_dir/data/icons/tilelane-test/32x32/apps/tilelane-test-badge.svg"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path fill="#808080" d="M0 0h32v32H0z"/></svg>' > "$test_dir/data/icons/tilelane-test/32x32/apps/application-x-executable.svg"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path fill="#ff0000" d="M0 0h32v32H0z"/></svg>' > "$test_dir/external/tilelane-test-badge.svg"
cp "$test_dir/external/tilelane-test-badge.svg" "$test_dir/external/tilelane-test-unknown"
cat > "$test_dir/shell.qml" <<'QML'
import QtQuick
import QtQuick.Window
import Quickshell
import "qml/components"

Window {
    id: window
    visible: true
    width: 160
    height: 32
    color: "black"
    Row {
        id: icons
        Repeater {
            model: ["image://icon/tilelane-test-badge", "image://icon/tilelane-test-badge?path=" + Quickshell.env("TEST_DIR") + "/external", "image://qsimage/1/2", "image://icon/" + Quickshell.env("TEST_DIR") + "/external/tilelane-test-badge.svg", "image://icon/tilelane-test-unknown?path=" + Quickshell.env("TEST_DIR") + "/external"]
            TrayIcon {
                required property string modelData
                source: modelData
                iconSize: 32
                foreground: "white"
            }
        }
    }
    Timer {
        running: true
        interval: 500
        onTriggered: icons.grabToImage(function(result) {
            if (!result.saveToFile(Quickshell.env("OUTPUT"))) {
                console.error("capture failed");
            }
            Qt.quit();
        })
    }
}
QML
# The inner shell expands TEST_DIR inside the private bus session.
# shellcheck disable=SC2016
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_SYSTEM_ICON_THEME=tilelane-test \
XDG_DATA_HOME="$test_dir/data" TEST_DIR="$test_dir" OUTPUT="$test_dir/native-provider.png" \
  timeout 15 dbus-run-session --config-file="$test_dir/bus.conf" -- sh -eu -c '
    dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus.ListActivatableNames > "$TEST_DIR/activatable.log"
    if dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.StartServiceByName string:org.freedesktop.portal.Desktop uint32:0 \
        > "$TEST_DIR/activation.log" 2>&1; then
      printf "Unexpected desktop portal activation\n" >&2
      exit 1
    fi
    exec quickshell --path "$TEST_DIR" --no-color
  ' > "$test_dir/runtime.log" 2>&1
[[ "$(rg -c 'string "' "$test_dir/activatable.log")" == 1 ]]
rg -q 'string "org.freedesktop.DBus"' "$test_dir/activatable.log"
rg -q 'org.freedesktop.DBus.Error.ServiceUnknown' "$test_dir/activation.log"
printf 'Private D-Bus: no activatable desktop services; portal activation rejected\n'
pixels=$(magick "$test_dir/native-provider.png" -format '%[pixel:p{16,16}] %[pixel:p{48,16}] %[pixel:p{80,16}] %[pixel:p{112,16}] %[pixel:p{144,16}]' info:)
printf '%s\n' "$pixels"
[[ "$pixels" == 'srgba(0,255,0,1) srgba(0,255,0,1) srgba(128,128,128,1) srgba(128,128,128,1) srgba(128,128,128,1)' ]]
printf 'Native provider: themed, path-stripped, opaque fallback, file fallback, missing-name fallback passed\n'
