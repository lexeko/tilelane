.pragma library

function stringList(value) {
    if (!value)
        return [];
    if (Array.isArray(value))
        return value.map(function (item) {
            return String(item || "");
        }).filter(function (item) {
            return item !== "";
        });
    return String(value).split(/[;,]/).map(function (item) {
        return item.trim();
    }).filter(function (item) {
        return item !== "";
    });
}

function normalizedDesktopId(value) {
    const id = String(value || "").trim();
    return id.slice(-8) === ".desktop" ? id.slice(0, -8) : id;
}

function desktopFileId(value) {
    // Quickshell removes the file suffix from entry.id. The remaining ID can
    // itself end in .desktop, as it does for Telegram.
    const id = String(value || "").trim();
    return id === "" ? "" : id + ".desktop";
}

function idSet(text) {
    const result = ({});
    const lines = String(text || "").split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const id = normalizedDesktopId(lines[index]);
        if (id && id.charAt(0) !== "#")
            result[id] = true;
    }
    return result;
}

function isHidden(entry, hiddenEntryIds) {
    if (!entry || entry.noDisplay === true)
        return true;
    const id = String(entry.id || "");
    return hiddenEntryIds && (hiddenEntryIds[id] === true || hiddenEntryIds[normalizedDesktopId(id)] === true);
}

function entryName(entry) {
    return String(entry && (entry.name || entry.genericName || entry.id) || "Application");
}

function indexEntries(values, hiddenEntryIds) {
    const result = [];
    values = values || [];
    for (let index = 0; index < values.length; index++) {
        const entry = values[index];
        if (!entry || !entry.id || isHidden(entry, hiddenEntryIds))
            continue;
        const name = entryName(entry);
        const genericName = String(entry.genericName || "");
        const keywords = stringList(entry.keywords);
        result.push({
            "id": String(entry.id),
            "name": name,
            "genericName": genericName,
            "icon": String(entry.icon || "application-x-executable"),
            "searchText": (name + " " + genericName + " " + entry.id + " " + keywords.join(" ")).toLocaleLowerCase()
        });
    }
    result.sort(function (left, right) {
        const byName = left.name.localeCompare(right.name);
        return byName !== 0 ? byName : left.id.localeCompare(right.id);
    });
    return result;
}

function filter(index, query) {
    const expected = String(query || "").trim().toLocaleLowerCase();
    const result = [];
    index = index || [];
    for (let itemIndex = 0; itemIndex < index.length; itemIndex++) {
        const item = index[itemIndex];
        if (expected !== "" && String(item.searchText || "").indexOf(expected) === -1)
            continue;
        result.push(item);
    }
    return result;
}

function pinnedFirst(entries, pinnedIds) {
    const source = entries || [];
    const pins = pinnedIds || [];
    const byId = ({});
    const emitted = ({});
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const entry = source[index];
        if (entry && entry.id)
            byId[String(entry.id)] = entry;
    }
    for (let index = 0; index < pins.length; index++) {
        const id = String(pins[index] || "");
        if (id !== "" && byId[id] && emitted[id] !== true) {
            result.push(byId[id]);
            emitted[id] = true;
        }
    }
    for (let index = 0; index < source.length; index++) {
        const entry = source[index];
        const id = String(entry && entry.id || "");
        if (id === "" || emitted[id] !== true)
            result.push(entry);
    }
    return result;
}

function movedIndex(current, offset, count) {
    if (count <= 0)
        return -1;
    return Math.max(0, Math.min(count - 1, (current < 0 ? 0 : current) + offset));
}
