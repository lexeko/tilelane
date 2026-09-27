.pragma library

function normalized(value) {
    return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "");
}

function programList(value) {
    var source = value;
    if (typeof source === "string") {
        try {
            source = JSON.parse(source);
        } catch (error) {
            source = [];
        }
    }
    if (!Array.isArray(source))
        return [];
    var result = [];
    for (var i = 0; i < source.length; i++) {
        var name = String(source[i] || "").trim();
        if (name !== "" && result.indexOf(name) === -1)
            result.push(name);
    }
    return result;
}

function commandParts(entry) {
    var command = entry && entry.command ? entry.command : [];
    var result = [];
    for (var i = 0; i < command.length; i++)
        result.push(String(command[i] || ""));
    return result;
}

function executableName(value) {
    var parts = String(value || "").split("/");
    return parts[parts.length - 1];
}

function terminalExecutable(entry) {
    if (!entry || entry.runInTerminal !== true)
        return "";
    var command = commandParts(entry);
    var index = 0;
    if (executableName(command[0]) === "env") {
        index++;
        while (index < command.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(command[index]))
            index++;
    }
    if (index >= command.length)
        return "";
    var executable = executableName(command[index]);
    if (["bash", "dash", "fish", "node", "python", "python3", "sh", "zsh"].indexOf(executable) !== -1)
        return "";
    return executable;
}

function terminalEntry(entries, programs) {
    var running = programList(programs);
    if (running.length === 0)
        return null;
    var matched = null;
    for (var i = 0; i < entries.length; i++) {
        var executable = terminalExecutable(entries[i]);
        if (executable === "" || running.indexOf(executable) === -1)
            continue;
        if (matched && String(matched.id || "") !== String(entries[i].id || ""))
            return null;
        matched = entries[i];
    }
    return matched;
}

function webAppHost(entry) {
    var command = commandParts(entry);
    if (command.length < 2 || executableName(command[0]) !== "omarchy-launch-webapp")
        return "";
    var match = String(command[1]).match(/^[a-z][a-z0-9+.-]*:\/\/(?:[^@/]+@)?([^:/?#]+)(?::[0-9]+)?(?:[/?#]|$)/i);
    return match ? String(match[1]).toLowerCase() : "";
}

function controlPressed(modifiers) {
    return (Number(modifiers || 0) & Qt.ControlModifier) !== 0;
}

function expectedWindowId(entry) {
    if (!entry)
        return "";
    return String(entry.startupClass || entry.id || "");
}

function webAppEntry(entries, appId) {
    var windowId = String(appId || "").toLowerCase();
    if (windowId === "")
        return null;
    var prefixes = ["brave-", "chromium-", "google-chrome-", "microsoft-edge-", "opera-", "vivaldi-", "helium-"];
    var matched = null;
    for (var i = 0; i < entries.length; i++) {
        var host = webAppHost(entries[i]);
        if (host === "")
            continue;
        var classMatches = false;
        for (var prefixIndex = 0; prefixIndex < prefixes.length; prefixIndex++) {
            if (windowId.indexOf(prefixes[prefixIndex] + host + "__") === 0) {
                classMatches = true;
                break;
            }
        }
        if (!classMatches)
            continue;
        if (matched && String(matched.id || "") !== String(entries[i].id || ""))
            return null;
        matched = entries[i];
    }
    return matched;
}

function validDesktopId(value) {
    var id = String(value || "");
    return id !== "" && id.length <= 512 && id.trim() === id && !/[\x00\r\n]/.test(id);
}

function entryById(entries, value) {
    var expected = String(value || "");
    if (expected === "")
        return null;
    for (var i = 0; i < entries.length; i++) {
        if (entries[i] && String(entries[i].id || "") === expected)
            return entries[i];
    }
    var normalizedExpected = normalized(expected);
    for (var j = 0; j < entries.length; j++) {
        if (entries[j] && normalized(entries[j].id) === normalizedExpected)
            return entries[j];
    }
    return null;
}

function reverseDnsSuffixEntry(entries, candidates) {
    var matched = null;
    for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
        var candidate = normalized(candidates[candidateIndex]);
        var separator = candidate.lastIndexOf(".");
        if (separator < 0 || separator === candidate.length - 1)
            continue;
        var suffix = candidate.slice(separator + 1);
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
            var entry = entries[entryIndex];
            if (!entry)
                continue;
            if (normalized(entry.id) !== suffix && normalized(entry.startupClass) !== suffix)
                continue;
            if (matched && String(matched.id || "") !== String(entry.id || ""))
                return null;
            matched = entry;
        }
    }
    return matched;
}

function identityCandidates(record) {
    var result = [];
    var values = [record ? record.desktopEntryId : "", record ? record.appId : "", record ? record.className : "", record ? record.initialClass : ""];
    for (var i = 0; i < values.length; i++) {
        var value = String(values[i] || "");
        if (value !== "" && result.indexOf(value) === -1)
            result.push(value);
    }
    return result;
}

function overrideId(record, overrides) {
    var candidates = identityCandidates(record);
    var values = overrides && typeof overrides === "object" ? overrides : ({});
    for (var i = 0; i < candidates.length; i++) {
        var exact = values[candidates[i]];
        if (validDesktopId(exact))
            return exact;
        var folded = values[normalized(candidates[i])];
        if (validDesktopId(folded))
            return folded;
    }
    return "";
}

function findEntry(entries, record, overrides) {
    var library = entries || [];
    var override = overrideId(record, overrides);
    if (override !== "")
        return entryById(library, override);

    var terminal = terminalEntry(library, record ? record.terminalPrograms : []);
    if (terminal)
        return terminal;

    var candidates = identityCandidates(record);
    for (var i = 0; i < candidates.length; i++) {
        var direct = entryById(library, candidates[i]);
        if (direct)
            return direct;
    }

    for (var j = 0; j < candidates.length; j++) {
        var expected = String(candidates[j]).toLowerCase();
        for (var n = 0; n < library.length; n++) {
            if (library[n] && String(library[n].startupClass || "").toLowerCase() === expected)
                return library[n];
        }
    }

    var reverseDns = reverseDnsSuffixEntry(library, candidates);
    if (reverseDns)
        return reverseDns;
    return webAppEntry(library, record ? record.appId : "");
}

function identity(entry, record) {
    var desktopId = entry ? String(entry.id || "") : "";
    var appId = String(record ? record.appId || "" : "");
    return {
        desktopId: desktopId,
        name: String(entry ? entry.name || "" : "") || appId || "Application",
        icon: String(entry ? entry.icon || "" : "") || "application-x-executable"
    };
}

function taskRecords(records, identityFor) {
    var result = [];
    for (var index = 0; index < records.length; index++) {
        var record = records[index];
        var resolved = identityFor(record);
        result.push({
            desktopId: resolved.desktopId,
            appName: resolved.name,
            iconName: resolved.icon,
            address: record.address,
            title: record.title,
            appId: record.appId,
            active: record.active === true,
            urgent: record.urgent === true,
            minimized: record.minimized === true,
            fullscreen: record.fullscreen === true,
            maximized: record.maximized === true,
            floating: record.floating === true,
            orderKey: Number(record.orderKey || index + 1)
        });
    }
    result.sort(function (first, second) {
        return first.orderKey - second.orderKey;
    });
    return result;
}
