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

python3 - "$test_dir" "${QT_QUICK_BACKEND:-gpu}" <<'PY'
from pathlib import Path
import json, subprocess, sys
folder = Path(sys.argv[1])
log = (folder/'runtime.log').read_text()
assert not any(error in log for error in ['TypeError', 'ReferenceError', 'Binding loop', 'Failed to load configuration']), log
metrics = json.loads(next(line.split('STATUS_METRICS ', 1)[1] for line in log.splitlines() if 'STATUS_METRICS ' in line))
for item in metrics:
    if item['name'] in ['Dropbox', 'Tailscale']:
        assert abs(item['paintedSize']-item['target']) < .05, item
raw = subprocess.check_output(['magick', str(folder/'icons.png'), '-depth', '8', 'rgb:-'])
width, height = map(int, subprocess.check_output(['magick', str(folder/'icons.png'), '-format', '%w %h', 'info:'], text=True).split())
assert len(raw) == width*height*3, len(raw)
dpr = width / 800
assert height / 320 == dpr
cell_size = round(80*dpr)
for i, item in enumerate(metrics):
    col, row = i % 10, i // 10
    points = [(x,y) for y in range(cell_size) for x in range(cell_size)
              if max(raw[((row*cell_size+y)*width+col*cell_size+x)*3:((row*cell_size+y)*width+col*cell_size+x)*3+3]) > 16]
    # Qt's software scene graph does not paint Qt Quick Shapes. Its native
    # painted-bounds contract is checked above; the GPU run checks the pixels.
    if item['name'] == 'Dropbox' and not points and 'software' in sys.argv[2:]:
        continue
    assert points, item
    left, right = min(x for x,y in points), max(x for x,y in points)
    top, bottom = min(y for x,y in points), max(y for x,y in points)
    extent = max(right-left+1, bottom-top+1)/dpr
    assert abs(extent-item['target']) <= 1.5, (item, extent)
    assert abs((left+right+1)/2/dpr-40) <= 1, (item, 'horizontal center')
    assert abs((top+bottom+1)/2/dpr-40) <= 1, (item, 'vertical center')
print('status icons: pass (native Dropbox/Tailscale, panel/battery/weather glyphs, tray; four UI scales)')
PY
