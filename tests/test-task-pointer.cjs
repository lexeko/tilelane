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
  dsp = { focus = function(value) return value end, window = { move = function(value) return value end } },
  dispatch = function(command)
    assert(options.no_warps == true)
    assert(options.warp_on_change_workspace == 0)
    assert(options.warp_on_toggle_special == 0)
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
assert(calls == 2)
checkRestored()
local fail = ${failure}
local ok, message = pcall(fail)
assert(not ok and message:find("simulated failure"))
checkRestored()
local minimize = ${fallback}
assert(minimize() == true)
assert(calls == 4)
checkRestored()
`;
  const result = spawnSync('lua', ['-'], { input: script, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || String(result.error || 'Lua execution failed'));
}
console.log('task pointer: pass (success, failure, fallback, and original preferences)');
