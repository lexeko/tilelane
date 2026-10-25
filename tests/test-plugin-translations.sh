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

await_state() {
  local query="$1"
  for ((attempt = 0; attempt < 60; attempt++)); do
    if jq -e "$query" "$case_dir/state.json" >/dev/null 2>&1; then
      return
    fi
    sleep 0.05
  done
  printf 'Plugin translations failed (%s): %s\n' "$scenario" "$query" >&2
  cat "$case_dir/result.log" >&2
  cat "$case_dir/state.json" >&2 || true
  return 1
}

for scenario in missing broken native; do
  case_dir="$test_dir/$scenario"
  mkdir -p "$case_dir/qml/models" "$case_dir/i18n" "$case_dir/Commons"
  cp "$repo_dir/qml/models/PluginTranslations.qml" "$case_dir/qml/models/"
  cp "$repo_dir/tests/quickshell/plugin-translations.qml" "$case_dir/shell.qml"
  cp "$repo_dir/i18n/en.json" "$case_dir/i18n/"
  printf 'en\n' > "$case_dir/i18n/language"
  if [[ "$scenario" == native ]]; then
    cp "$repo_dir/tests/fixtures/translations/Translations.qml" "$case_dir/Commons/"
  elif [[ "$scenario" == broken ]]; then
    printf 'import QtQuick\nUnavailableType {}\n' > "$case_dir/Commons/Translations.qml"
  fi

  # Exercise real QML component loading, FileView and reactive text bindings.
  # These isolated offscreen shells create no desktop surfaces.
  QT_QPA_PLATFORM=offscreen QSG_RHI_BACKEND=software \
    quickshell --path "$case_dir" --no-color > "$case_dir/result.log" 2>&1 &
  shell_pid=$!
  await_state '.missing == "unknown.key" and .fallback == "Fallback" and .emptyFallback == ""'
  if [[ "$scenario" == native ]]; then
    await_state '.native and .later == "Native later"'
    printf 'fr\n' > "$case_dir/i18n/language"
    await_state '.native and .later == "Plus tard"'
    printf 'en\n' > "$case_dir/i18n/language"
    await_state '.native and .later == "Native later"'
  else
    await_state '(.native | not) and .later == "Later" and .title == "Give Tilelane more room" and .choice == "Move dock Left and turn on auto-hide"'
    printf '{"tips.later":"Updated"}\n' > "$case_dir/i18n/en.json"
    await_state '.later == "Updated" and .title == "tips.dock.title"'
    printf 'invalid json\n' > "$case_dir/i18n/en.json"
    await_state '.later == "tips.later" and .fallback == "Fallback"'
    cp "$repo_dir/i18n/en.json" "$case_dir/i18n/en.json"
    await_state '.later == "Later"'
  fi
  kill "$shell_pid"
  wait "$shell_pid" || true
  shell_pid=""
done
printf 'plugin translations: pass (missing/broken native component, English catalogs, native delegation and live language changes)\n'
