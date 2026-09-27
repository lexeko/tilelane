.pragma library

function records(settings, metadata) {
    settings = settings || {};
    metadata = metadata || {};
    var source = settings.items;
    if (!Array.isArray(source) || source.length === 0)
        source = settings.indicators;
    if (!Array.isArray(source) || source.length === 0) {
        source = [];
        var schema = metadata.schema || [];
        for (var i = 0; i < schema.length; i++) {
            if (schema[i].key === "items") {
                source = (schema[i].options || []).map(function (option) { return option.value; });
                break;
            }
        }
    }
    var occurrences = {};
    return source.reduce(function (result, entry) {
        var id = typeof entry === "string" ? entry : entry && entry.id;
        // Indicators are named QML files beside the native widget directory.
        // Do not allow settings to turn an ID into an arbitrary source path.
        if (typeof id !== "string" || !/^[A-Za-z][A-Za-z0-9_-]*$/.test(id))
            return result;
        var values = {};
        if (entry && typeof entry === "object") {
            for (var key in entry) {
                if (key !== "id") values[key] = entry[key];
            }
        }
        var occurrence = occurrences[id] || 0;
        occurrences[id] = occurrence + 1;
        result.push({key: id + ":" + occurrence, indicatorId: id, settingsJson: JSON.stringify(values)});
        return result;
    }, []);
}
