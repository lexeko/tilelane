.pragma library

var minimizedWorkspace = "special:tilelane-minimized";

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

function activationDispatches(address, workspaceName) {
    var target = selector(address);
    if (target === "")
        return [];

    var result = [];
    var workspace = String(workspaceName || "");
    if (workspace !== "" && workspace !== minimizedWorkspace)
        result.push("hl.dsp.focus({ workspace = " + luaString(workspace) + " })");
    result.push("hl.dsp.focus({ window = " + luaString(target) + " })");
    return result;
}

function restoreDispatches(address, workspaceName) {
    var target = selector(address);
    var workspace = String(workspaceName || "");
    if (target === "" || workspace === "" || workspace === minimizedWorkspace)
        return [];

    var windowArg = "window = " + luaString(target);
    return ["hl.dsp.window.move({ workspace = " + luaString(workspace) + ", follow = false, " + windowArg + " })", "hl.dsp.focus({ workspace = " + luaString(workspace) + " })", "hl.dsp.focus({ " + windowArg + " })"];
}

function fallbackCode(action, address, workspaceName) {
    var target = selector(address);
    if (target === "")
        return "";
    var windowArg = "window = " + luaString(target);
    if (action === "activate")
        return "return hl.dispatch(hl.dsp.focus({ " + windowArg + " }))";
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
