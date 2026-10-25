const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');

const logic = {};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../qml/TaskLogic.js'), 'utf8').replace(/^\.pragma library\s*/, ''), logic);
assert.equal(logic.withoutCursorWarp(''), '');
assert.equal(logic.pointerStableDispatch([]), '');

for (const originalNoWarps of [false, true]) {
  const normal = logic.pointerStableDispatch(logic.activationDispatches('0xabc', '2'));
  const failure = logic.withoutCursorWarp('hl.dispatch(hl.dsp.focus({ window = "address:0xabc" })); error("simulated failure")');
  const fallback = logic.withoutCursorWarp(logic.fallbackCode('minimize', '0xabc', ''));
  const script = `
local options = { no_warps = ${originalNoWarps}, warp_on_change_workspace = 1, warp_on_toggle_special = 2 }
local calls = 0
hl = {
  get_config = function(key) return options[key:match("cursor%.(.+)")] end,
  config = function(value) for key, v in pairs(value.cursor) do options[key] = v end end,
  dsp = { focus = function(value) return value end, window = { move = function(value) return value end, alter_zorder = function(value) return value end } },
  dispatch = function(command)
    assert(options.no_warps == true)
    assert(options.warp_on_change_workspace == 0)
    assert(options.warp_on_toggle_special == 0)
    if type(command) == "function" then return command() end
    calls = calls + 1
    return true
  end
}
local function checkRestored()
  assert(options.no_warps == ${originalNoWarps})
  assert(options.warp_on_change_workspace == 1)
  assert(options.warp_on_toggle_special == 2)
end
local activate = ${normal}
activate()
assert(calls == 4)
checkRestored()
local fail = ${failure}
local ok, message = pcall(fail)
assert(not ok and message:find("simulated failure"))
checkRestored()
local minimize = ${fallback}
assert(minimize() == true)
assert(calls == 6)
checkRestored()
`;
  const result = spawnSync('lua', ['-'], { input: script, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || String(result.error || 'Lua execution failed'));
}
console.log('task pointer: pass (success, failure, fallback, and original preferences)');

for (const raiseMode of ['refocus-pointer', 'normal', 'missing', 'throws']) {
  for (const operation of ['activate', 'restore', 'fallback']) {
    const commands = operation === 'activate'
      ? logic.pointerStableDispatch(logic.activationDispatches('0xabc', '2'))
      : operation === 'restore'
        ? logic.pointerStableDispatch(logic.restoreDispatches('0xabc', '2'))
        : logic.withoutCursorWarp(logic.fallbackCode('activate', '0xabc', ''));
    const script = `
local options = { no_warps = false, warp_on_change_workspace = 1, warp_on_toggle_special = 2 }
local active, raised = "other-window", false
local events = {}
hl = {
  get_config = function(key) return options[key:match("cursor%.(.+)")] end,
  config = function(value) for key, v in pairs(value.cursor) do options[key] = v end end,
  dsp = {
    focus = function(value) return { kind = "focus", window = value.window } end,
    window = {
      move = function(value) return { kind = "move" } end,
      alter_zorder = function(value)
        ${raiseMode === 'throws' ? 'error("raise unavailable")' : ''}
        return { kind = "raise", window = value.window }
      end
    }
  },
  dispatch = function(command)
    assert(options.no_warps and options.warp_on_change_workspace == 0 and options.warp_on_toggle_special == 0)
    if type(command) == "function" then return command() end
    table.insert(events, command.kind)
    if command.kind == "focus" and command.window then active = command.window end
    if command.kind == "raise" then
      raised = true
      ${raiseMode === 'refocus-pointer' ? 'active = "under-pointer"' : ''}
    end
    return true
  end
}
${raiseMode === 'missing' ? 'hl.dsp.window.alter_zorder = nil' : ''}
local action = ${commands}
action()
assert(active == "address:0xabc", "requested window lost focus: " .. active)
assert(events[#events] == "focus", "focus must be the final action")
assert(raised == ${['normal', 'refocus-pointer'].includes(raiseMode)})
assert(options.no_warps == false and options.warp_on_change_workspace == 1 and options.warp_on_toggle_special == 2)
`;
    const result = spawnSync('lua', ['-'], { input: script, encoding: 'utf8' });
    assert.equal(result.status, 0, `${operation}/${raiseMode}: ${result.stderr || result.error}`);
  }
}
console.log('task focus: pass (activation, restore, fallback; native, pointer-refocusing, missing, and failing raise)');
