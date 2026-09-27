.pragma library

// Match Omarchy's routing: close an already-open panel first, otherwise
// summon on the focused output, falling back to the available bar surface.
function pickHost(candidates, focusedScreen) {
    const rows = candidates.filter(function(row) { return !!row; });
    const opened = rows.filter(function(row) { return row.opened; });
    const pool = opened.length > 0 ? opened : rows;
    for (let index = 0; index < pool.length; index++) {
        if (focusedScreen && pool[index].screenName === focusedScreen)
            return pool[index].host;
    }
    return pool.length > 0 ? pool[0].host : null;
}

function panelIdAt(candidates, index, focusedScreen) {
    const visible = candidates.filter(function(row) { return row && row.visible; });
    const focused = visible.filter(function(row) { return row.screenName === focusedScreen; });
    const screen = focused.length > 0 ? focusedScreen : visible.length > 0 ? visible[0].screenName : "";
    const ordered = visible.filter(function(row) { return row.screenName === screen; });
    ordered.sort(function(a, b) { return a.x - b.x; });
    const row = ordered[Math.round(Number(index)) - 1];
    return row ? row.host.moduleName : "";
}
