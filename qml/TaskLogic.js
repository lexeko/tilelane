.pragma library

var minimizedWorkspace = "special:tilelane-minimized";
var omarchyMinimizedWorkspace = "special:minimized";

function primaryAction(active, minimized) {
    if (minimized === true)
        return "restore";
    return active === true ? "minimize" : "activate";
}

function displayTitle(title, appId) {
    var cleanTitle = String(title || "").trim();
    if (cleanTitle !== "")
        return cleanTitle;
    var cleanApp = String(appId || "").trim();
    return cleanApp !== "" ? cleanApp : "Application";
}

function visualState(pressed, focused, hovered, launching, urgent, active, minimized) {
    if (pressed === true)
        return "pressed";
    if (focused === true)
        return "focused";
    if (hovered === true)
        return "hovered";
    if (launching === true)
        return "launching";
    if (urgent === true)
        return "urgent";
    if (active === true)
        return "active";
    if (minimized === true)
        return "minimized";
    return "idle";
}

function validAddress(address) {
    return /^0x[0-9a-f]{1,16}$/i.test(String(address || ""));
}

function validWorkspaceId(value) {
    var id = String(value || "");
    return /^[1-9][0-9]*$/.test(id) && Number(id) <= 2147483647;
}

function cleanOrigins(origins) {
    var result = ({});
    if (!origins || typeof origins !== "object" || Array.isArray(origins))
        return result;

    for (var address in origins) {
        var normalized = String(address || "").toLowerCase();
        var workspace = origins[address];
        if (!validAddress(normalized) || typeof workspace !== "string")
            continue;
        if (workspace.trim() === "" || workspace === minimizedWorkspace || workspace.length > 255)
            continue;
        result[normalized] = workspace;
    }
    return result;
}

function parseOrigins(text) {
    try {
        var payload = JSON.parse(String(text || ""));
        if (!payload || payload.version !== 1)
            return ({});
        return cleanOrigins(payload.origins);
    } catch (error) {
        return ({});
    }
}

function serializeOrigins(origins) {
    return JSON.stringify({
        version: 1,
        origins: cleanOrigins(origins)
    }, null, 2) + "\n";
}

function luaString(value) {
    return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\r/g, "\\r").replace(/\n/g, "\\n") + "\"";
}

function selector(address) {
    return validAddress(address) ? "address:" + String(address) : "";
}

function withoutCursorWarp(code) {
    if (String(code || "").trim() === "")
        return "";
    // One synchronous compositor action: suppress warps before any focus or
    // workspace change, and restore the user's options even if dispatch fails.
    return "function() "
        + "local saved = { no_warps = hl.get_config(\"cursor.no_warps\"), warp_on_change_workspace = hl.get_config(\"cursor.warp_on_change_workspace\"), warp_on_toggle_special = hl.get_config(\"cursor.warp_on_toggle_special\") }; "
        + "hl.config({ cursor = { no_warps = true, warp_on_change_workspace = 0, warp_on_toggle_special = 0 } }); "
        + "local ok, result = pcall(function() " + code + " end); "
        + "hl.config({ cursor = saved }); "
        + "if not ok then error(result) end; return result end";
}

function pointerStableDispatch(commands) {
    if (!commands || commands.length === 0)
        return "";
    return withoutCursorWarp(commands.map(function (command) {
        return "hl.dispatch(" + command + ")";
    }).join("; "));
}

function guardedRaiseDispatch(target) {
    // Raising can refocus the window under the pointer on older compositors.
    // Keep it optional and let the following exact focus win in every path.
    return "function() pcall(function() hl.dispatch(hl.dsp.window.alter_zorder({ mode = \"top\", window = " + luaString(target) + " })) end) end";
}

function activeWorkspaceId(monitor) {
    var id = monitor && monitor.activeWorkspace ? Number(monitor.activeWorkspace.id) : 0;
    return Number.isInteger(id) && id > 0 && id <= 2147483647 ? String(id) : "";
}

function restoreWorkspaceForMonitor(monitorName, monitors, focusedMonitor) {
    var name = String(monitorName || "");
    if (name !== "") {
        var available = monitors || [];
        for (var i = 0; i < available.length; i++) {
            if (String(available[i].name || "") === name) {
                var workspace = activeWorkspaceId(available[i]);
                if (workspace !== "")
                    return workspace;
            }
        }
    }
    return activeWorkspaceId(focusedMonitor);
}

function canMinimizeToOmarchyDock(record, wayland) {
    return !!record && record.omarchyFloatingWorkspace === true
        && Number.isInteger(Number(record.workspaceId)) && Number(record.workspaceId) > 0
        && canAppearInOmarchyDock(wayland);
}

function canAppearInOmarchyDock(wayland) {
    return !!wayland && String(wayland.appId || "") !== "" && !wayland.parent;
}

function dockMigrationCode(address, workspaceId, tags) {
    var target = selector(address);
    var workspace = String(workspaceId || "");
    if (target === "" || !validWorkspaceId(workspace))
        return "";

    var originTag = "omarchy-minimized-from-" + workspace;
    var windowArg = "window = " + luaString(target);
    var commands = [];
    var count = tags && typeof tags.length === "number" ? Math.min(tags.length, 256) : 0;
    for (var i = 0; i < count; i++) {
        var tag = String(tags[i] || "");
        if (/^omarchy-minimized-from-[1-9][0-9]*$/.test(tag) && tag !== originTag)
            commands.push("hl.dispatch(hl.dsp.window.tag({ tag = " + luaString("-" + tag) + ", " + windowArg + " }))");
    }
    commands.push("hl.dispatch(hl.dsp.window.tag({ tag = " + luaString("+" + originTag) + ", " + windowArg + " }))");
    commands.push("hl.dispatch(hl.dsp.window.move({ workspace = " + luaString(omarchyMinimizedWorkspace) + ", follow = false, " + windowArg + " }))");
    return "local window = hl.get_window(" + luaString(target) + "); "
        + "if not window or not window.workspace or window.workspace.name ~= " + luaString(minimizedWorkspace) + " then return false end; "
        + "local active = hl.get_active_workspace(); "
        + "local focus = active and active.id and active.id >= 1 and tostring(active.id) or " + luaString(workspace) + "; "
        + commands.join("; ") + "; hl.dispatch(hl.dsp.focus({ workspace = focus }))";
}

function activationDispatches(address, workspaceName) {
    var target = selector(address);
    if (target === "")
        return [];

    var result = [];
    var workspace = String(workspaceName || "");
    if (workspace !== "" && workspace !== minimizedWorkspace)
        result.push("hl.dsp.focus({ workspace = " + luaString(workspace) + " })");
    result.push("hl.dsp.focus({ window = " + luaString(target) + " })");
    result.push(guardedRaiseDispatch(target));
    result.push("hl.dsp.focus({ window = " + luaString(target) + " })");
    return result;
}

function restoreDispatches(address, workspaceName) {
    var target = selector(address);
    var workspace = String(workspaceName || "");
    if (target === "" || workspace === "" || workspace === minimizedWorkspace)
        return [];

    var windowArg = "window = " + luaString(target);
    return ["hl.dsp.window.move({ workspace = " + luaString(workspace) + ", follow = false, " + windowArg + " })"].concat(activationDispatches(address, workspace));
}

function fallbackCode(action, address, workspaceName) {
    var target = selector(address);
    if (target === "")
        return "";
    var windowArg = "window = " + luaString(target);
    if (action === "activate")
        return activationDispatches(address, "").map(function (command) {
            return "hl.dispatch(" + command + ")";
        }).join("; ");
    if (action === "close")
        return "return hl.dispatch(hl.dsp.window.close({ " + windowArg + " }))";
    if (action === "minimize")
        return "return hl.dispatch(hl.dsp.window.move({ workspace = " + luaString(minimizedWorkspace) + ", follow = false, " + windowArg + " }))";
    if (action === "restore" && String(workspaceName || "") !== "")
        return "return hl.dispatch(hl.dsp.window.move({ workspace = " + luaString(workspaceName) + ", follow = false, " + windowArg + " }))";
    if (action === "maximize")
        return "return hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", " + windowArg + " }))";
    if (action === "float")
        return "return hl.dispatch(hl.dsp.window.float({ action = \"toggle\", " + windowArg + " }))";
    return "";
}
