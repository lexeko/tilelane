#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export TILELANE_TEST_LOG="$test_dir/log"
export TILELANE_TEST_STATE="$test_dir/state"

cat >"$test_dir/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'hyprctl' >>"$TILELANE_TEST_LOG"
printf '\t%s' "$@" >>"$TILELANE_TEST_LOG"
printf '\n' >>"$TILELANE_TEST_LOG"
if [[ "${1:-}" == "repl" ]]; then
  printf '%s\n' "${TILELANE_TEST_CONTROL:-false}"
elif [[ "${1:-}" == "-j" && "${2:-}" == "clients" ]]; then
  if [[ -s "$TILELANE_TEST_STATE" ]]; then
    cat "$TILELANE_TEST_STATE"
  else
    printf '[]\n'
  fi
elif [[ "${1:-}" == "eval" ]]; then
  if [[ -n "${TILELANE_TEST_AFTER:-}" ]]; then
    printf '%s\n' "$TILELANE_TEST_AFTER" >"$TILELANE_TEST_STATE"
  fi
  printf 'ok\n'
elif [[ "${1:-}" == "dispatch" ]]; then
  printf 'ok\n'
fi
EOF

cat >"$test_dir/bin/uwsm-app" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uwsm-app' >>"$TILELANE_TEST_LOG"
printf '\t%s' "$@" >>"$TILELANE_TEST_LOG"
printf '\n' >>"$TILELANE_TEST_LOG"
EOF

cat >"$test_dir/bin/xdg-terminal-exec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--print-id" ]]; then
  printf 'foot.desktop\n'
fi
EOF

chmod 755 "$test_dir/bin/hyprctl" "$test_dir/bin/uwsm-app" "$test_dir/bin/xdg-terminal-exec"
export PATH="$test_dir/bin:$PATH"

reset_case() {
  : >"$TILELANE_TEST_LOG"
  : >"$TILELANE_TEST_STATE"
  export TILELANE_TEST_CONTROL=false
  export TILELANE_TEST_AFTER=""
}

fail() {
  printf 'launch helper test failed: %s\n' "$1" >&2
  exit 1
}

reset_case
bash "$repo_dir/scripts/launch-application" auto 0 "App With Space.desktop" ExampleApp ""
grep -F $'uwsm-app\t--\tgtk-launch\tApp With Space.desktop' "$TILELANE_TEST_LOG" >/dev/null || fail "ordinary pointer launch changed"
if grep -F $'hyprctl\teval' "$TILELANE_TEST_LOG" >/dev/null; then
  fail "ordinary pointer launch requested floating"
fi

reset_case
export TILELANE_TEST_CONTROL=true
export TILELANE_TEST_AFTER='[{"address":"0xabc","class":"ExampleApp","initialClass":"ExampleApp","floating":false,"focusHistoryID":0}]'
bash "$repo_dir/scripts/launch-application" auto 0 "Example.desktop" ExampleApp ""
grep -F $'hyprctl\trepl' "$TILELANE_TEST_LOG" >/dev/null || fail "compositor Ctrl state was not checked"
grep -F '{ float = true }' "$TILELANE_TEST_LOG" >/dev/null || fail "Ctrl launch omitted the one-shot floating rule"
grep -F 'address:0xabc' "$TILELANE_TEST_LOG" >/dev/null || fail "single-instance fallback did not float the new matching window"

reset_case
printf '%s\n' '[{"address":"0x111","class":"NativeApp","floating":false}]' >"$TILELANE_TEST_STATE"
export TILELANE_TEST_AFTER='[{"address":"0x111","class":"NativeApp","floating":false},{"address":"0x222","class":"NativeApp","initialClass":"NativeApp","floating":false},{"address":"0x333","class":"UnrelatedApp","floating":false,"focusHistoryID":0}]'
bash "$repo_dir/scripts/launch-application" floating 1 "NativeApp.desktop" legacy.NativeApp ""
grep -F 'address:0x222' "$TILELANE_TEST_LOG" >/dev/null || fail "native desktop ID was not used when StartupWMClass differs"
if grep -E 'dispatch.*address:0x(111|333)' "$TILELANE_TEST_LOG" >/dev/null; then
  fail "native fallback changed an existing or unrelated window"
fi

for launch_mode in auto floating; do
  for window_class in org.example.desktop ChangedClass; do
    reset_case
    export TILELANE_TEST_AFTER='[{"address":"0x456","class":"'"$window_class"'","initialClass":"org.example.desktop","floating":false,"focusHistoryID":0}]'
    bash "$repo_dir/scripts/launch-application" "$launch_mode" 1 "org.example.desktop.desktop" LegacyExample ""
    grep -F 'address:0x456' "$TILELANE_TEST_LOG" >/dev/null || fail "window ID ending in .desktop did not match its desktop file"
  done
done

reset_case
export TILELANE_TEST_AFTER='[{"address":"0xdef","class":"brave-youtube.com__-Default","initialClass":"brave-youtube.com__-Default","floating":true,"focusHistoryID":0}]'
bash "$repo_dir/scripts/launch-application" floating 1 "YouTube.desktop" YouTube youtube.com
grep -F '{ float = true }' "$TILELANE_TEST_LOG" >/dev/null || fail "explicit floating launch was not requested"
if grep -F $'hyprctl\tdispatch' "$TILELANE_TEST_LOG" >/dev/null; then
  fail "already-floating web app received a redundant dispatch"
fi

reset_case
export TILELANE_TEST_AFTER='[{"address":"0x123","class":"foot","initialClass":"foot","floating":true,"focusHistoryID":0}]'
bash "$repo_dir/scripts/launch-application" floating 1 "cliamp.desktop" cliamp "" 1
grep -F '{ float = true }' "$TILELANE_TEST_LOG" >/dev/null || fail "terminal application was not launched floating"
if [[ "$(grep -Fc $'hyprctl\t-j\tclients' "$TILELANE_TEST_LOG")" -ne 2 ]]; then
  fail "terminal host identity did not end fallback tracking promptly"
fi

reset_case
place_uri="file:///tmp/Folder with spaces"
bash "$repo_dir/scripts/launch-application" auto 0 org.gnome.Nautilus.desktop org.gnome.Nautilus "" 0 "$place_uri"
grep -F $'uwsm-app\t--\tnautilus\t--new-window\t--\t'"$place_uri" "$TILELANE_TEST_LOG" >/dev/null || fail "ordinary place launch lost its URI"
if grep -F $'hyprctl\teval' "$TILELANE_TEST_LOG" >/dev/null; then
  fail "ordinary place launch requested floating"
fi

for launch_mode in auto floating; do
  reset_case
  printf '%s\n' '[{"address":"0x111","class":"org.gnome.Nautilus","floating":false}]' >"$TILELANE_TEST_STATE"
  export TILELANE_TEST_AFTER='[{"address":"0x111","class":"org.gnome.Nautilus","floating":false},{"address":"0x222","class":"org.gnome.Nautilus","floating":false}]'
  bash "$repo_dir/scripts/launch-application" "$launch_mode" 1 org.gnome.Nautilus.desktop org.gnome.Nautilus "" 0 "$place_uri"
  grep -F "nautilus --new-window -- '$place_uri'" "$TILELANE_TEST_LOG" >/dev/null || fail "floating place launch lost its URI"
  grep -F 'address:0x222' "$TILELANE_TEST_LOG" >/dev/null || fail "new Files window did not float"
  if grep -E 'dispatch.*address:0x111' "$TILELANE_TEST_LOG" >/dev/null; then
    fail "floating place launch changed the existing Files window"
  fi
done

if bash "$repo_dir/scripts/launch-application" floating 1 $'bad\n.desktop' Bad "" >/dev/null 2>&1; then
  fail "invalid desktop ID was accepted"
fi

printf 'launch helper: pass\n'
