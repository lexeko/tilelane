#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

# Load the production model without a compositor connection. Synthetic records
# exercise its actual ListModel updates, revisions, ordering, and source cleanup.
mkdir -p "$test_dir/qml/models" "$test_dir/fixtures"
cp "$repo_dir/tests/quickshell/window-model.qml" "$test_dir/shell.qml"
cp "$repo_dir/qml/models/WindowModel.qml" "$repo_dir/qml/models/WindowState.js" "$test_dir/qml/models/"
cp "$repo_dir/tests/fixtures/WindowFixtures.js" "$test_dir/fixtures/"
if ! env -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen \
    timeout 10 quickshell --path "$test_dir" --no-color >"$test_dir/result.log" 2>&1; then
  cat "$test_dir/result.log"
  exit 1
fi
if ! rg -q 'WINDOW MODEL PASS' "$test_dir/result.log" || \
    rg -q 'WINDOW MODEL FAIL|TypeError|ReferenceError|Binding loop' "$test_dir/result.log"; then
  cat "$test_dir/result.log"
  exit 1
fi
printf 'window model: pass (opening order, updates, stale close, lookups, source cleanup)\n'
