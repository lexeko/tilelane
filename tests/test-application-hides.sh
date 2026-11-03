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

mkdir -p "$test_dir/default/omarchy" "$test_dir/data/applications" "$test_dir/home"
cp -r "$repo_dir/qml" "$repo_dir/scripts" "$test_dir/"
cp "$repo_dir/tests/quickshell/application-hides.qml" "$test_dir/shell.qml"
for name in first second; do
  printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\n' "$name" > "$test_dir/data/applications/$name.desktop"
done
hides_path="$test_dir/default/omarchy/launcher.hides"
printf 'first.desktop\n' > "$hides_path"

# The production catalog watches real temporary files and indexes two fixtures.
env -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen \
  TILELANE_HIDES_TEST_DIR="$test_dir" HOME="$test_dir/home" \
  XDG_DATA_HOME="$test_dir/data" XDG_DATA_DIRS="$test_dir/data" \
  quickshell --path "$test_dir" --no-color > "$test_dir/result.log" 2>&1 &
shell_pid=$!

await_state() {
  local query="$1" label="$2"
  for ((attempt = 0; attempt < 60; attempt++)); do
    if jq -e "$query" "$test_dir/state.json" >/dev/null 2>&1; then
      return
    fi
    sleep 0.05
  done
  printf 'Application hides failed: %s\n' "$label" >&2
  cat "$test_dir/result.log" >&2
  cat "$test_dir/state.json" >&2 || true
  return 1
}

await_state '.listed == ["second"] and .hidden == ["first"]' 'initial hides'
printf 'second.desktop\n' > "$hides_path"
await_state '.listed == ["first"] and .hidden == ["second"]' 'in-place hide and unhide'
printf 'first.desktop\nsecond.desktop\n' > "$test_dir/replacement"
mv "$test_dir/replacement" "$hides_path"
await_state '.listed == [] and .hidden == ["first", "second"]' 'atomic replacement'
: > "$hides_path"
await_state '.listed == ["first", "second"] and .hidden == []' 'empty list'
printf 'first.desktop\nsecond.desktop\n' > "$hides_path"
await_state '.listed == []' 'hide before deletion'
rm "$hides_path"
await_state '.listed == ["first", "second"] and .hidden == []' 'deleted list'
printf 'second.desktop\n' > "$hides_path"
await_state '.listed == ["first"] and .hidden == ["second"]' 'recreated list'
if rg -n 'TypeError|ReferenceError|Binding loop|ERROR|Failed to load' "$test_dir/result.log"; then
  exit 1
fi
printf 'Application hides: pass (initial, in-place, atomic, empty, deleted and recreated lists)\n'
