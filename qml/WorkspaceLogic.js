.pragma library

function validId(value) {
    const id = Math.round(Number(value));
    return isFinite(id) && id >= 1 && id <= 10 ? id : 0;
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
