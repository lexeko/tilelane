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
trap 'cat "$test_dir/result.log" >&2' ERR
mkdir -p "$test_dir/qml/components" "$test_dir/plugin"
cp "$repo_dir/tests/quickshell/hosted-lifecycle.qml" "$test_dir/shell.qml"
for name in HostedBarWidget HostedObjectTree NativeIpcRegistry WidgetManifest; do
  cp "$repo_dir/qml/components/$name.qml" "$test_dir/qml/components/"
done
cp "$repo_dir/qml/StatusWidgetLogic.js" "$test_dir/qml/"
cp "$repo_dir/tests/fixtures/hosted-lifecycle/"* "$test_dir/plugin/"
QT_QPA_PLATFORM=offscreen TILELANE_WIDGET_TEST_DIR="$test_dir" \
  quickshell --path "$test_dir" --no-color >"$test_dir/result.log" 2>&1 &
shell_pid=$!
ipc() { quickshell ipc --pid "$shell_pid" call "$@"; }
await_state() {
  for ((attempt = 0; attempt < 80; attempt++)); do
    if ipc test.control state 2>/dev/null | jq -e "$1" >/dev/null 2>&1; then return; fi
    sleep 0.05
  done
  cat "$test_dir/result.log" >&2
  return 1
}
await_state '.first and .second and .labels == 1'
[[ "$(ipc example.nested identity)" == first ]]
ipc example.nested refresh
await_state '.counts == [1, 1]'
ipc test.control focus second
[[ "$(ipc example.nested identity)" == second ]]
ipc test.control nested false
await_state '.labels == 0'
[[ "$(ipc example.nested identity)" == first ]]
ipc test.control nested true
await_state '.labels == 1'
[[ "$(ipc example.nested identity)" == second ]]
ipc test.control focus first
ipc test.control removeFirst
await_state '(.first | not) and .second'
[[ "$(ipc example.nested identity)" == second ]]
ipc test.control restoreFirst
await_state '.first and .second'
[[ "$(ipc example.nested identity)" == first ]]
ipc test.control configure false example.nested
disabled_result="$(ipc example.nested identity 2>&1 || true)"
[[ "$disabled_result" != first && "$disabled_result" != second ]]
ipc test.control nested false
await_state '.labels == 0'
ipc test.control nested true
await_state '.labels == 1'
ipc test.control focus second
ipc test.control configure true example.renamed
[[ "$(ipc example.renamed identity)" == second ]]
ipc test.control focus first
[[ "$(ipc example.renamed identity)" == first ]]
ipc test.control unload
await_state '(.first | not) and (.second | not)'
if rg -n 'Handler was registered|non-bindable|TypeError|ReferenceError|Binding loop|LIFECYCLE FAIL' "$test_dir/result.log"; then
  exit 1
fi
printf 'hosted lifecycle: pass (nested IPC, monitor handoff, broadcast, recreation, teardown)\n'
