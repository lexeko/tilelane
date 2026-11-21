.pragma library

var shortcutAppId = "tilelane";
var shortcutName = "start.toggle";
var shortcutTarget = shortcutAppId + ":" + shortcutName;
var bindings = ["SUPER + Super_L", "SUPER + Super_R"];
var stateTable = "__tilelane_super_start";

function enableLua() {
    const keys = bindings.map(function (key) {
        return JSON.stringify(key);
    }).join(", ");
    const target = JSON.stringify(shortcutTarget);
    return "local t = _G." + stateTable + "; "
        + "if type(t) ~= 'table' then t = {}; _G." + stateTable + " = t end; "
        + "for _, k in ipairs({" + keys + "}) do "
        + "local b = t[k]; "
        + "if b == nil or tostring(b) == 'HL.Keybind(expired)' then "
        + "b = hl.bind(k, hl.dsp.global(" + target + "), { release = true }); "
        + "t[k] = b "
        + "end; "
        + "if b ~= nil and tostring(b) ~= 'HL.Keybind(expired)' then b:set_enabled(true) end "
        + "end";
}

function disableLua() {
    return "local t = _G." + stateTable + "; "
        + "if type(t) == 'table' then "
        + "for _, b in pairs(t) do "
        + "if b ~= nil and tostring(b) ~= 'HL.Keybind(expired)' then b:set_enabled(false) end "
        + "end "
        + "end";
}

function syncLua(enabled) {
    return enabled === true ? enableLua() : disableLua();
}

function shouldHandleReload(eventName, enabled) {
    return enabled === true && String(eventName || "") === "configreloaded";
}

function pickStartMenuToggle(menus, focusedMonitorName) {
    const list = Array.isArray(menus) ? menus : [];
    const openIndices = [];
    for (let index = 0; index < list.length; index++) {
        if (list[index] && list[index].open === true)
            openIndices.push(index);
    }
    if (openIndices.length > 0) {
        return {
            action: "close",
            indices: openIndices
        };
    }
    const expected = String(focusedMonitorName || "");
    if (expected !== "") {
        for (let index = 0; index < list.length; index++) {
            const entry = list[index];
            if (entry && String(entry.screenName || "") === expected) {
                return {
                    action: "open",
                    index: index
                };
            }
        }
    }
    for (let index = 0; index < list.length; index++) {
        if (list[index]) {
            return {
                action: "open",
                index: index
            };
        }
    }
    return {
        action: "none",
        index: -1
    };
}
