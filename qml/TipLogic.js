.pragma library

// A tip has a stable ID so dismissing it does not hide future tips.
function select(tips, dismissed, hidden) {
    const ignored = (dismissed || []).concat(hidden || []);
    for (const tip of tips || []) {
        if (tip && tip.eligible === true && ignored.indexOf(tip.id) === -1)
            return tip;
    }
    return null;
}

function dockOverlap(state) {
    return !!state && state.dockEnabled === true && state.dockPosition === "bottom" && state.dockAutohide === false && state.barPosition === "bottom" && state.workspaceMode === "floating" && state.fullscreenMode === 0 && state.screenName !== "";
}
