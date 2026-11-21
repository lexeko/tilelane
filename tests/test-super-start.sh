#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
shell_pid=""
stop_shell() {
  if [[ -n "$shell_pid" ]]; then
    kill "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
    shell_pid=""
  fi
}
cleanup() {
  stop_shell
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

# 1. Verify the generated Lua payloads against a stub Hyprland Lua runtime.
if command -v node >/dev/null 2>&1 && command -v lua >/dev/null 2>&1; then
  node - "$repo_dir/qml/SuperStartLogic.js" <<'NODE' >"$test_dir/payloads.lua"
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8').replace(/^\s*\.pragma\s+library\s*$/m, '');
const ctx = vm.createContext({});
vm.runInContext(source, ctx);
console.log('ENABLE_LUA = ' + JSON.stringify(ctx.enableLua()));
console.log('DISABLE_LUA = ' + JSON.stringify(ctx.disableLua()));
NODE

  lua - "$test_dir/payloads.lua" <<'LUA'
dofile(arg[1])

local binds = {}
local dispatches = {}
local unbind_calls = 0

local function make_keybind(keys, callback, opts)
  local kb = {
    keys = keys,
    callback = callback,
    opts = opts or {},
    enabled = true,
    expired = false,
  }
  return setmetatable(kb, {
    __tostring = function(self)
      return self.expired and "HL.Keybind(expired)" or ("HL.Keybind(" .. self.keys .. ")")
    end,
    __index = {
      set_enabled = function(self, value)
        assert(not self.expired, "dereferenced expired keybind handle")
        self.enabled = value == true
      end,
      is_enabled = function(self)
        assert(not self.expired, "dereferenced expired keybind handle")
        return self.enabled
      end,
      remove = function()
        error("Tilelane must not call :remove() because it expires user binds on the same chord")
      end,
      unbind = function()
        error("Tilelane must not call :unbind() because it expires user binds on the same chord")
      end,
    },
  })
end

hl = {
  dsp = {
    global = function(target)
      return { kind = "global", target = target }
    end,
  },
  dispatch = function(action)
    table.insert(dispatches, action)
  end,
  bind = function(keys, callback, opts)
    local kb = make_keybind(keys, callback, opts)
    table.insert(binds, kb)
    return kb
  end,
  unbind = function()
    unbind_calls = unbind_calls + 1
    error("Tilelane must not call hl.unbind()")
  end,
}

-- Simulate a pre-existing user binding on Super_L.
local user_bind = hl.bind("SUPER + Super_L", function() end, { release = true, description = "User bind" })

-- Disable before enable is a safe no-op.
assert(load(DISABLE_LUA))()
assert(#binds == 1 and user_bind:is_enabled())

-- Enable binds Super_L and Super_R with release=true and no description.
assert(load(ENABLE_LUA))()
assert(#binds == 3, "expected 2 Tilelane binds in addition to user bind")
for i = 2, 3 do
  assert(binds[i].opts.release == true, "expected release=true")
  assert(binds[i].opts.description == nil, "runtime Lua bind must omit description")
  assert(binds[i]:is_enabled(), "expected enabled bind")
end

-- Invoking a Tilelane bind dispatches the global shortcut.
assert(type(binds[2].callback) == "table" and binds[2].callback.kind == "global" and binds[2].callback.target == "tilelane:start.toggle")
assert(type(binds[3].callback) == "table" and binds[3].callback.kind == "global" and binds[3].callback.target == "tilelane:start.toggle")

-- Re-enabling reuses existing handles instead of duplicating binds.
assert(load(ENABLE_LUA))()
assert(#binds == 3, "re-enabling must not create duplicate binds")

-- Disabling turns off only Tilelane's handles and leaves the user's bind active.
assert(load(DISABLE_LUA))()
assert(unbind_calls == 0)
assert(user_bind:is_enabled(), "user bind must remain enabled")
assert(not binds[2]:is_enabled() and not binds[3]:is_enabled(), "Tilelane binds must be disabled")

-- Expired handles (e.g. after Hyprland reload) are skipped safely on disable and recreated on enable.
binds[2].expired = true
binds[3].expired = true
assert(load(DISABLE_LUA))()
assert(load(ENABLE_LUA))()
assert(#binds == 5, "expected fresh handles after expiration")
assert(binds[4]:is_enabled() and binds[5]:is_enabled())
LUA
fi

# 2. Verify SuperStartController lifecycle with a mocked hyprctl on PATH.
mkdir -p "$test_dir/bin" "$test_dir/qml/models"
cat >"$test_dir/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TILELANE_SUPER_START_TEST_DIR/hyprctl.log"
printf 'ok\n'
SH
chmod +x "$test_dir/bin/hyprctl"

cp "$repo_dir/tests/quickshell/super-start.qml" "$test_dir/shell.qml"
cp "$repo_dir/qml/models/SuperStartController.qml" "$test_dir/qml/models/"
cp "$repo_dir/qml/SuperStartLogic.js" "$test_dir/qml/"
printf '{"id":0}\n' >"$test_dir/action.json"
: >"$test_dir/hyprctl.log"

PATH="$test_dir/bin:$PATH" \
  QT_QPA_PLATFORM=offscreen \
  TILELANE_SUPER_START_TEST_DIR="$test_dir" \
  quickshell --path "$test_dir" --no-color >"$test_dir/result.log" 2>&1 &
shell_pid=$!

await_state() {
  local query="$1" label="$2"
  for ((attempt = 0; attempt < 100; attempt++)); do
    if jq -e "$query" "$test_dir/state.json" >/dev/null 2>&1; then return; fi
    sleep 0.05
  done
  printf 'Super start controller failed: %s\n' "$label" >&2
  cat "$test_dir/result.log" >&2 || true
  cat "$test_dir/state.json" >&2 || true
  cat "$test_dir/hyprctl.log" >&2 || true
  return 1
}

await_log_lines() {
  local count="$1" label="$2"
  for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ "$(wc -l <"$test_dir/hyprctl.log")" -ge "$count" ]]; then return; fi
    sleep 0.05
  done
  printf 'Super start hyprctl log count failed: %s\n' "$label" >&2
  cat "$test_dir/hyprctl.log" >&2 || true
  return 1
}

await_state '.ready and (.enabled | not) and .triggers == 0' 'initial disabled state'
await_log_lines 1 'initial disabled sync'
tail -n 1 "$test_dir/hyprctl.log" | grep -q 'set_enabled(false)'

printf '{"id":1,"kind":"press"}\n' >"$test_dir/action.json"
await_state '.actionId == 1 and .triggers == 0' 'shortcut ignored while disabled'

printf '{"id":2,"kind":"set","value":true}\n' >"$test_dir/action.json"
await_state '.actionId == 2 and .enabled and .hasApplied' 'enable super start'
await_log_lines 2 'enable sync executed'
tail -n 1 "$test_dir/hyprctl.log" | grep -q 'set_enabled(true)'

printf '{"id":3,"kind":"release"}\n' >"$test_dir/action.json"
await_state '.actionId == 3 and .triggers == 1' 'release shortcut triggers while enabled'

printf '{"id":4,"kind":"set","value":false}\n' >"$test_dir/action.json"
await_state '.actionId == 4 and (.enabled | not)' 'disable super start'
await_log_lines 3 'disable sync executed'
tail -n 1 "$test_dir/hyprctl.log" | grep -q 'set_enabled(false)'

printf '{"id":5,"kind":"press"}\n' >"$test_dir/action.json"
await_state '.actionId == 5 and .triggers == 1' 'shortcut ignored again after disable'

printf '{"id":6,"kind":"set","value":true}\n' >"$test_dir/action.json"
await_state '.actionId == 6 and .enabled' 're-enable before shutdown'
await_log_lines 4 're-enable sync executed'

printf '{"id":7,"kind":"shutdown"}\n' >"$test_dir/action.json"
await_state '.actionId == 7 and .shuttingDown' 'shutdown disables runtime bind'
await_log_lines 5 'shutdown disable executed'
tail -n 1 "$test_dir/hyprctl.log" | grep -q 'set_enabled(false)'

printf '{"id":8,"kind":"press"}\n' >"$test_dir/action.json"
await_state '.actionId == 8 and .triggers == 1' 'shortcut ignored after shutdown'

printf 'Super-key Start controller: pass\n'
