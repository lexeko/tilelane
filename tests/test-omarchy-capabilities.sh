#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
shell_pid=""
quickshell_bin="$(command -v quickshell)"
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
  for ((attempt = 0; attempt < 100; attempt++)); do
    if jq -e "$query" "$case_dir/state.json" >/dev/null 2>&1; then return; fi
    sleep 0.05
  done
  printf 'Capability regression failed (%s): %s\n' "$scenario" "$query" >&2
  cat "$case_dir/result.log" >&2
  cat "$case_dir/state.json" >&2 || true
  return 1
}

for scenario in missing layout minimize both; do
  case_dir="$test_dir/$scenario"
  mkdir -p "$case_dir/bin" "$case_dir/qml/models" "$case_dir/state/omarchy/workspace-layouts"
  ln -s /bin/sh "$case_dir/bin/sh"
  cp "$repo_dir/qml/models/OmarchyCapabilities.qml" "$repo_dir/qml/models/WorkspaceModeMonitor.qml" "$case_dir/qml/models/"
  cp "$repo_dir/tests/quickshell/omarchy-capabilities.qml" "$case_dir/shell.qml"
  printf 'dwindle\n' > "$case_dir/state/omarchy/workspace-layouts/default.lua"
  if [[ "$scenario" == layout || "$scenario" == both ]]; then
    cat > "$case_dir/bin/omarchy-hyprland-workspace-layout-current" <<'SH'
#!/bin/sh
printf '%s\n' "$1" >> "$XDG_STATE_HOME/probes"
IFS= read -r mode < "$XDG_STATE_HOME/omarchy/workspace-layouts/default.lua"
printf '%s\n' "$mode"
SH
    chmod +x "$case_dir/bin/omarchy-hyprland-workspace-layout-current"
  fi
  if [[ "$scenario" == minimize || "$scenario" == both ]]; then
    printf '#!/bin/sh\nexit 0\n' > "$case_dir/bin/omarchy-hyprland-window-minimize"
    chmod +x "$case_dir/bin/omarchy-hyprland-window-minimize"
  fi

  # Restrict command discovery to test helpers, independently of the host version.
  PATH="$case_dir/bin" XDG_STATE_HOME="$case_dir/state" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --path "$case_dir" --no-color > "$case_dir/result.log" 2>&1 &
  shell_pid=$!
  await_state '.checked'
  if [[ "$scenario" == layout || "$scenario" == both ]]; then
    await_state '.layout and .active and .retry and .mode == "dwindle" and .watchCount == 1'
    printf 'floating\n' > "$case_dir/state/omarchy/workspace-layouts/default.lua"
    await_state '.mode == "floating"'
    printf 'dwindle\n' > "$case_dir/state/omarchy/workspace-layouts/default.lua"
    await_state '.mode == "dwindle"'
    [[ -s "$case_dir/state/probes" ]]
  else
    await_state '(.layout | not) and (.active | not) and (.retry | not) and .mode == "" and .directoryWatch == "" and .watchCount == 0'
    [[ ! -e "$case_dir/state/probes" ]]
  fi
  if [[ "$scenario" == minimize || "$scenario" == both ]]; then
    await_state '.minimize'
  else
    await_state '(.minimize | not)'
  fi
  if rg -q 'Process failed to start|TypeError|ReferenceError' "$case_dir/result.log"; then
    cat "$case_dir/result.log" >&2
    exit 1
  fi
  kill "$shell_pid"
  wait "$shell_pid" || true
  shell_pid=""
done
printf 'Omarchy capabilities: pass (absent, partial, full; live workspace-mode changes)\n'
