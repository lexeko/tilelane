.pragma library

function clampFraction(value) {
    const number = Number(value);
    if (!isFinite(number))
        return 0;
    return Math.max(0, Math.min(1, number));
}

function wifiIcon(connected, strength) {
    if (!connected)
        return "󰤮";
    const icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
    const index = Math.max(0, Math.min(4, Math.ceil(clampFraction(strength) * 5) - 1));
    return icons[index];
}

function batteryIcon(present, percentage, charging, fullyCharged, thresholdActive) {
    if (!present)
        return "";
    const chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
    const defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
    const index = Math.max(0, Math.min(9, Math.floor(clampFraction(percentage) * 10)));
    if (thresholdActive)
        return defaultIcons[index];
    if (fullyCharged)
        return "󰂅";
    return charging ? chargingIcons[index] : defaultIcons[index];
}

function trayItemNamed(item, name) {
    if (!item)
        return false;
    var expected = String(name || "").toLowerCase();
    return [item.id, item.title, item.tooltipTitle].some(function (value) {
        return String(value || "").toLowerCase().indexOf(expected) !== -1;
    });
}

function activeTrayItems(items, passiveStatus, excludedNames) {
    const values = items || [];
    const excluded = excludedNames || [];
    const result = [];
    for (let index = 0; index < values.length; index++) {
        const item = values[index];
        if (!item || item.status === passiveStatus)
            continue;
        let owned = false;
        for (let nameIndex = 0; nameIndex < excluded.length; nameIndex++) {
            if (trayItemNamed(item, excluded[nameIndex])) {
                owned = true;
                break;
            }
        }
        if (!owned)
            result.push(item);
    }
    return result;
}
