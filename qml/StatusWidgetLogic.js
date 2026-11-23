.pragma library

var layoutSections = ["left", "centerBegin", "center", "centerEnd", "right"];
var informationSections = ["centerBegin", "center", "centerEnd"];

function presentation(id) {
    if (["omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor"].indexOf(id) !== -1)
        return "panel";
    if (id === "omarchy.power") return "power";
    if (id === "omarchy.clock") return "clock";
    if (id === "omarchy.tray") return "tray";
    if (id === "omarchy.keyboard-layout") return "text";
    if (id === "omarchy.weather") return "weather";
    return "native";
}

function entryId(entry) {
    return typeof entry === "string" ? entry : entry && typeof entry.id === "string" ? entry.id : "";
}

function widgetSettings(config, id) {
    var target = typeof id === "string" ? id : "";
    if (!target)
        return {id: ""};
    var layout = config && config.layout ? config.layout : {};
    for (var sectionIndex = 0; sectionIndex < layoutSections.length; sectionIndex++) {
        var entries = Array.isArray(layout[layoutSections[sectionIndex]]) ? layout[layoutSections[sectionIndex]] : [];
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
            var entry = entries[entryIndex];
            if (entryId(entry) === target)
                return entry && typeof entry === "object" ? entry : {id: target};
        }
    }
    return {id: target};
}

function records(config, registry) {
    var layout = config && config.layout ? config.layout : {};
    var widgets = registry || {};
    var result = [];
    var occurrences = {};
    layoutSections.forEach(function (section) {
        var entries = Array.isArray(layout[section]) ? layout[section] : [];
        entries.forEach(function (entry) {
            var id = entryId(entry);
            // Tilelane supplies these surfaces itself, including the Start
            // menu's indicators. Do not instantiate duplicate native widgets.
            if (!id || ["omarchy.menu", "omarchy.workspaces", "omarchy.indicators"].indexOf(id) !== -1 || !widgets[id])
                return;
            var metadata = widgets[id].metadata || {};
            var occurrence = occurrences[id] || 0;
            if (occurrence > 0 && metadata.allowMultiple !== true)
                return;
            occurrences[id] = occurrence + 1;
            var settings = Object.assign({}, metadata.defaults || {}, typeof entry === "object" ? entry : {}, {id: id});
            result.push({
                key: id + ":" + occurrence,
                widgetId: id,
                section: section,
                groupName: id === "omarchy.clock" ? "clock" : informationSections.indexOf(section) !== -1 ? "information" : "controls",
                presentation: presentation(id),
                settingsJson: JSON.stringify(settings)
            });
        });
    });
    // Keep configured order within each group, with the clock at the edge.
    return ["controls", "information", "clock"].reduce(function (ordered, group) {
        return ordered.concat(result.filter(function (record) { return record.groupName === group; }));
    }, []);
}

function sameRecord(left, right) {
    return left.key === right.key && left.widgetId === right.widgetId && left.section === right.section && left.groupName === right.groupName && left.presentation === right.presentation && left.settingsJson === right.settingsJson;
}

function manifestEntryPoint(text) {
    try {
        var manifest = JSON.parse(text);
        var path = manifest.entryPoints && manifest.entryPoints.barWidget;
        if (typeof path !== "string" || path === "" || path[0] === "/" || /[\\%?#]/.test(path) || path.split("/").indexOf("..") !== -1)
            return "";
        return path;
    } catch (error) {
        return "";
    }
}
