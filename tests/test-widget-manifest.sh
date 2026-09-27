#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
shell_pid=""
cleanup() {
  if [[ -n "$shell_pid" ]]; then
    kill "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
  fi
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/qml/components" "$test_dir/plugin/views"
cp "$repo_dir/tests/quickshell/widget-manifest.qml" "$test_dir/shell.qml"
cp "$repo_dir/qml/components/HostedBarWidget.qml" "$repo_dir/qml/components/WidgetManifest.qml" "$repo_dir/qml/components/HostedObjectTree.qml" "$test_dir/qml/components/"
cp "$repo_dir/qml/StatusWidgetLogic.js" "$test_dir/qml/"
for label in First Second; do
  cat > "$test_dir/plugin/views/$label.qml" <<QML
import QtQuick
Item {
    property string label: "$label"
    property string moduleName: ""
    property var settings: ({})
}
QML
done
printf '%s\n' '{"entryPoints":{"barWidget":"views/First.qml"}}' > "$test_dir/plugin/manifest.json"

# Exercise the real FileView and Loader against temporary files without
# creating desktop windows or changing the installed plugin registry.
QT_QPA_PLATFORM=offscreen TILELANE_WIDGET_TEST_DIR="$test_dir" \
  quickshell --path "$test_dir" --no-color > "$test_dir/result.log" 2>&1 &
shell_pid=$!

await_state() {
  local query="$1"
  for ((attempt = 0; attempt < 60; attempt++)); do
    if jq -e "$query" "$test_dir/state.json" >/dev/null 2>&1; then
      return
    fi
    sleep 0.05
  done
  printf 'Widget manifest regression failed: %s\n' "$query" >&2
  cat "$test_dir/result.log" >&2
  cat "$test_dir/state.json" >&2 || true
  return 1
}

await_state '.available and .label == "First" and .moduleName == "test.manifest" and .setting == "Injected"'
printf '%s\n' '{"entryPoints":{"barWidget":"views/Second.qml"}}' > "$test_dir/plugin/manifest.json"
await_state '.available and .label == "Second"'
printf '%s\n' '{"entryPoints":{"barWidget":"../Outside.qml"}}' > "$test_dir/plugin/manifest.json"
await_state '(.available | not) and .entryPoint == ""'
printf '%s\n' '{"entryPoints":{"barWidget":"views/First.qml"}}' > "$test_dir/plugin/replacement"
mv "$test_dir/plugin/replacement" "$test_dir/plugin/manifest.json"
await_state '.available and .label == "First"'
printf 'widget manifest: pass\n'
