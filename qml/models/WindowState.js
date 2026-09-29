.pragma library

var minimizedWorkspace = "special:tilelane-minimized";
var terminalProbeMarker = "__tilelane_terminal_host__";

function parseTerminalProbe(text) {
    var programs = [];
    var ownsTerminal = false;
    var lines = String(text || "").split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var name = lines[i].trim();
        if (name === terminalProbeMarker) {
            ownsTerminal = true;
        } else if (name !== "" && programs.indexOf(name) === -1) {
            programs.push(name);
        }
    }
    return {
        ownsTerminal: ownsTerminal,
        programs: programs
    };
}

function retryTerminalProbe(result, attempts, maximum) {
    // A wrapper process is not the terminal application's final identity.
    // Allow one recheck before the PTY appears, then finish the bounded
    // startup checks for terminals even when a shell/launcher was found.
    return attempts < maximum && (result.ownsTerminal || attempts === 1);
}

function stringValue(value, fallback) {
    if (value === undefined || value === null)
        return fallback || "";
    return String(value);
}

function numberValue(value, fallback) {
    var number = Number(value);
    return isFinite(number) ? number : (fallback || 0);
}

function creationOrder(stableId) {
    // Hyprland's stableId is a hexadecimal creation counter, not an address
    // or a focus-history index. It survives shell reloads and window moves.
    var value = typeof stableId === "number" ? stableId : /^(?:0x)?[0-9a-f]+$/i.test(String(stableId || "")) ? parseInt(String(stableId), 16) : 0;
    return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function normalizeAddress(value) {
    var address = stringValue(value, "").trim();
    if (/^0x[0-9a-f]+$/i.test(address))
        return "0x" + address.slice(2).toLowerCase();
    if (/^[0-9a-f]+$/i.test(address))
        return "0x" + address.toLowerCase();
    return address;
}

function preferredAppId(value) {
    var candidates = [value.waylandAppId, value.appId, value.className, value.initialClass, value.desktopEntryId];
    for (var i = 0; i < candidates.length; i++) {
        var candidate = stringValue(candidates[i], "").trim();
        if (candidate !== "")
            return candidate;
    }
    return "Application";
}

function normalizedPrograms(value) {
    var source = value;
    if (typeof source === "string") {
        try {
            source = JSON.parse(source);
        } catch (error) {
            source = [];
        }
    }
    if (!Array.isArray(source))
        source = [];
    var result = [];
    for (var i = 0; i < source.length; i++) {
        var name = stringValue(source[i], "").trim();
        if (name !== "" && result.indexOf(name) === -1)
            result.push(name);
    }
    return JSON.stringify(result);
}

function normalizeRecord(value) {
    var address = normalizeAddress(value.address);
    var workspaceName = stringValue(value.workspaceName, "");
    var appId = preferredAppId(value);
    var title = stringValue(value.title, "").trim();
    return {
        address: address,
        handle: address,
        title: title !== "" ? title : appId,
        appId: appId,
        className: stringValue(value.className, ""),
        initialClass: stringValue(value.initialClass, ""),
        pid: Math.max(0, Math.round(numberValue(value.pid, 0))),
        terminalPrograms: normalizedPrograms(value.terminalPrograms),
        desktopEntry: stringValue(value.desktopEntryId, ""),
        desktopEntryId: stringValue(value.desktopEntryId, ""),
        workspaceId: Math.round(numberValue(value.workspaceId, 0)),
        workspaceName: workspaceName,
        monitorId: Math.round(numberValue(value.monitorId, -1)),
        monitorName: stringValue(value.monitorName, ""),
        active: value.active === true,
        urgent: value.urgent === true,
        minimized: value.minimized === true || workspaceName === minimizedWorkspace,
        fullscreen: value.fullscreen === true,
        maximized: value.maximized === true,
        floating: value.floating === true,
        mapped: value.mapped !== false,
        hidden: value.hidden === true,
        xwayland: value.xwayland === true,
        hasWaylandHandle: value.hasWaylandHandle === true,
        orderKey: Math.max(0, Math.round(numberValue(value.orderKey, 0))),
        generation: Math.max(0, Math.round(numberValue(value.generation, 0)))
    };
}

var roleNames = ["address", "handle", "title", "appId", "className", "initialClass", "pid", "terminalPrograms", "desktopEntry", "desktopEntryId", "workspaceId", "workspaceName", "monitorId", "monitorName", "active", "urgent", "minimized", "fullscreen", "maximized", "floating", "mapped", "hidden", "xwayland", "hasWaylandHandle", "orderKey", "generation"];

function copyRecord(value) {
    var copy = {};
    for (var i = 0; i < roleNames.length; i++) {
        var role = roleNames[i];
        copy[role] = value[role];
    }
    return copy;
}

function sameRecord(first, second) {
    if (!first || !second)
        return false;
    for (var i = 0; i < roleNames.length; i++) {
        var role = roleNames[i];
        if (first[role] !== second[role])
            return false;
    }
    return true;
}

function visibleOnMonitor(record, monitorName, workspacePolicy, workspaceName) {
    if (!record || record.address === "" || !record.mapped || record.hidden)
        return false;
    if (monitorName !== "" && record.monitorName !== monitorName)
        return false;
    if (record.minimized)
        return true;
    return !(workspacePolicy === "active" && workspaceName !== "" && record.workspaceName !== workspaceName);
}

function filterRecords(records, monitorName, workspacePolicy, workspaceName) {
    var result = [];
    for (var i = 0; i < records.length; i++) {
        if (visibleOnMonitor(records[i], monitorName, workspacePolicy, workspaceName))
            result.push(copyRecord(records[i]));
    }
    return result;
}
