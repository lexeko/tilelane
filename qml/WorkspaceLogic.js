.pragma library
.import "TaskLogic.js" as TaskLogic

function validId(value) {
    const id = Number(value);
    return isFinite(id) && Math.floor(id) === id && id >= 1 && id <= 2147483647 ? id : 0;
}

function blockOf(id) {
    return Math.floor((validId(id) - 1) / 10);
}

function label(id) {
    return validId(id) > 0 ? String((Number(id) - 1) % 10 + 1) : "";
}

function parseBlocks(text) {
    const blocks = ({});
    const lines = String(text || "").split("\n");
    for (let index = 0; index < lines.length; index++) {
        const fields = lines[index].split("\t");
        if (fields.length < 3 || !/^\d+$/.test(fields[0]) || !fields[1] || !fields[2])
            continue;
        const block = Number(fields[0]);
        if (block <= 214748363)
            blocks[fields[1]] = block;
    }
    return blocks;
}

function monitorBlock(blocks, values, monitorName) {
    if (Object.prototype.hasOwnProperty.call(blocks, monitorName))
        return blocks[monitorName];
    return Math.max(0, blockOf(activeIdForMonitor(values, monitorName)));
}

function monitorWorkspaceIds(values, defaultCount, block, monitorName) {
    if (!monitorName)
        return [];
    const base = block * 10;
    const ids = workspaceIds([], defaultCount).map(function (id) { return base + id; });
    const guests = [];
    values = values || [];
    for (let index = 0; index < values.length; index++) {
        const workspace = values[index];
        const id = validId(workspace ? workspace.id : 0);
        if (id === 0)
            continue;
        if (blockOf(id) === block) {
            if (ids.indexOf(id) === -1)
                ids.push(id);
        } else if (workspace.monitor && workspace.monitor.name === monitorName && guests.indexOf(id) === -1) {
            guests.push(id);
        }
    }
    ids.sort(function (left, right) { return left - right; });
    guests.sort(function (left, right) { return left - right; });
    return ids.concat(guests);
}

function focusCommand(id, block, monitorName) {
    const target = validId(id);
    if (!target || !monitorName)
        return "";
    if (blockOf(target) === block)
        return "o.workspaces.focus(" + label(target) + ", " + TaskLogic.luaString(monitorName) + ")";
    return 'hl.dsp.focus({ workspace = "' + target + '" })';
}

function workspaceIds(values, defaultCount) {
    const count = Math.max(1, Math.min(10, Math.round(Number(defaultCount || 5))));
    const ids = [];
    for (let id = 1; id <= count; id++)
        ids.push(id);

    values = values || [];
    for (let index = 0; index < values.length; index++) {
        const id = validId(values[index] ? values[index].id : 0);
        if (id > 0 && ids.indexOf(id) === -1)
            ids.push(id);
    }
    ids.sort(function (left, right) {
        return left - right;
    });
    return ids;
}

function sourceFor(values, id) {
    values = values || [];
    for (let index = 0; index < values.length; index++) {
        if (Number(values[index] ? values[index].id : 0) === id)
            return values[index];
    }
    return null;
}

function activeIdForMonitor(values, monitorName) {
    if (!monitorName)
        return 0;
    values = values || [];
    for (let index = 0; index < values.length; index++) {
        const workspace = values[index];
        if (workspace && workspace.active === true && workspace.monitor && workspace.monitor.name === monitorName)
            return Math.max(0, Number(workspace.id) || 0);
    }
    return 0;
}

function records(values, focusedId, defaultCount) {
    const result = [];
    const ids = workspaceIds(values, defaultCount);
    for (let index = 0; index < ids.length; index++) {
        const id = ids[index];
        const source = sourceFor(values, id);
        const monitor = source ? source.monitor : null;
        const toplevels = source && source.toplevels ? source.toplevels.values || [] : [];
        result.push({
            "id": id,
            "name": source ? String(source.name || id) : String(id),
            "focused": id === Number(focusedId || 0),
            "active": source ? source.active === true : false,
            "urgent": source ? source.urgent === true : false,
            "fullscreen": source ? source.hasFullscreen === true : false,
            "occupied": toplevels.length > 0,
            "monitorName": monitor ? String(monitor.name || "") : ""
        });
    }
    return result;
}

function sameRecord(left, right) {
    return left.id === right.id && left.name === right.name && left.focused === right.focused && left.active === right.active && left.urgent === right.urgent && left.fullscreen === right.fullscreen && left.occupied === right.occupied && left.monitorName === right.monitorName;
}
