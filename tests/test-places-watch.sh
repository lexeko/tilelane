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

mkdir -p "$test_dir/qml/models"
cp "$repo_dir/tests/quickshell/places-watch.qml" "$test_dir/shell.qml"
cp "$repo_dir/qml/models/PlacesModel.qml" "$test_dir/qml/models/"
cp "$repo_dir/qml/PlacesLogic.js" "$test_dir/qml/"
printf 'file:///tmp/documents Documents\nfile:///tmp/downloads Downloads\n' >"$test_dir/bookmarks"
printf 'file:///tmp/legacy Legacy\n' >"$test_dir/legacy-bookmarks"
printf 'XDG_DOCUMENTS_DIR="/tmp/documents"\n' >"$test_dir/user-dirs.dirs"

# The real model watches only temporary files. No desktop windows are created.
QT_QPA_PLATFORM=offscreen TILELANE_PLACES_TEST_DIR="$test_dir" \
  quickshell --path "$test_dir" --no-color >"$test_dir/result.log" 2>&1 &
shell_pid=$!

await_state() {
  local query="$1"
  local label="$2"
  for ((attempt = 0; attempt < 60; attempt++)); do
    if jq -e "$query" "$test_dir/state.json" >/dev/null 2>&1; then
      return
    fi
    sleep 0.05
  done
  printf 'Places watcher failed: %s\n' "$label" >&2
  cat "$test_dir/result.log" >&2
  cat "$test_dir/state.json" >&2 || true
  return 1
}

await_state '.available and ([.places[].name] == ["Documents", "Downloads"])' 'initial bookmarks'

# Files saves bookmarks by replacing the file. Keep watching the replacement.
printf 'file:///tmp/documents Documents\n' >"$test_dir/replacement"
mv "$test_dir/replacement" "$test_dir/bookmarks"
await_state '([.places[].name] == ["Documents"])' 'removed bookmark'

printf 'file:///tmp/documents Work\n' >"$test_dir/replacement"
mv "$test_dir/replacement" "$test_dir/bookmarks"
await_state '([.places[].name] == ["Work"])' 'renamed bookmark'

printf 'file:///tmp/downloads Downloads\nfile:///tmp/documents Work\n' >"$test_dir/bookmarks"
await_state '([.places[].name] == ["Downloads", "Work"])' 'added and reordered bookmarks'

: >"$test_dir/bookmarks"
await_state '.available and (.places | length == 0)' 'empty file must not fall back to legacy bookmarks'

rm "$test_dir/bookmarks"
await_state '(.available | not) and ([.places[].name] == ["Legacy"])' 'deleted file uses legacy bookmarks'

printf 'file:///tmp/legacy Renamed legacy\n' >"$test_dir/legacy-bookmarks"
await_state '([.places[].name] == ["Renamed legacy"])' 'legacy bookmark change'

printf 'file:///tmp/documents Documents\n' >"$test_dir/bookmarks"
await_state '.available and ([.places[].name] == ["Documents"])' 'recreated file takes priority'
await_state '.places[0].iconName == "folder-documents-symbolic"' 'directory icon'

printf 'XDG_DOWNLOAD_DIR="/tmp/documents"\n' >"$test_dir/user-dirs.dirs"
await_state '.places[0].iconName == "folder-download-symbolic"' 'changed user directory icon'

printf 'Places watcher: pass\n'
