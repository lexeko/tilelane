#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

# Exercise the real controller with a fake window model. No windows are opened
# or compositor commands dispatched; journal writes stay in temporary storage.
mkdir -p "$test_dir/qml/models"
cp "$repo_dir/tests/quickshell/minimize-lifecycle.qml" "$test_dir/shell.qml"
cp "$repo_dir/qml/models/WindowActions.qml" "$test_dir/qml/models/"
cp "$repo_dir/qml/TaskLogic.js" "$test_dir/qml/"
if ! QT_QPA_PLATFORM=offscreen XDG_STATE_HOME="$test_dir/state" \
    timeout 10 quickshell --path "$test_dir" --no-color >"$test_dir/result.log" 2>&1; then
  cat "$test_dir/result.log"
  exit 1
fi
if ! rg -q 'LIFECYCLE PASS' "$test_dir/result.log"; then
  cat "$test_dir/result.log"
  exit 1
fi
printf 'minimize lifecycle: pass\n'
