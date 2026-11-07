#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
omarchy_root="${OMARCHY_PATH:-/usr/share/omarchy}"
test_dir=$(mktemp -d)
cleanup() {
  local status=$?
  if ((status != 0)); then
    cat "$test_dir/runtime.log" >&2 || true
  fi
  rm -rf -- "$test_dir"
}
trap cleanup EXIT
cp -r "$repo_dir/qml" "$test_dir/"
cp "$repo_dir/tests/quickshell/status-icons.qml" "$test_dir/shell.qml"
ln -s "$omarchy_root/shell/Commons" "$test_dir/Commons"
ln -s "$omarchy_root/shell/Ui" "$test_dir/Ui"
mkdir -p "$test_dir/data/icons/hicolor/scalable/apps" "$test_dir/home"
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
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><path fill="white" d="M0 0h32v32H0z"/></svg>' \
  > "$test_dir/data/icons/hicolor/scalable/apps/tilelane-status-fixture.svg"
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
if [[ "${QSG_RHI_BACKEND:-software}" == "software" ]]; then
  export QT_QUICK_BACKEND=software
  unset QSG_RHI_BACKEND
fi
HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/data" XDG_DATA_DIRS="$test_dir/data" \
  OMARCHY_ROOT="$omarchy_root" OUTPUT="$test_dir/icons.png" \
  QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" QT_QPA_PLATFORMTHEME='' QT_QPA_SYSTEM_ICON_THEME=hicolor \
  dbus-run-session --config-file="$test_dir/bus.conf" -- \
  timeout 15 quickshell --path "$test_dir" --no-color > "$test_dir/runtime.log" 2>&1

node "$repo_dir/tests/check-status-icons.cjs" "$test_dir" "${QT_QUICK_BACKEND:-gpu}"
