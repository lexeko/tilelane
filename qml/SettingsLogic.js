.pragma library
.import "AppIdentity.js" as AppIdentity

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function pins(value) {
    if (!Array.isArray(value))
        throw new Error("pins must be an array");
    const result = [];
    for (let index = 0; index < value.length; index++) {
        const id = value[index];
        if (typeof id !== "string" || !AppIdentity.validDesktopId(id))
            throw new Error("invalid desktop-entry ID");
        if (result.indexOf(id) === -1)
            result.push(id);
    }
    return result;
}

function overrides(value) {
    if (!isObject(value))
        throw new Error("identity overrides must be an object");
    const keys = Object.keys(value);
    for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        if (!AppIdentity.validDesktopId(key) || typeof value[key] !== "string" || !AppIdentity.validDesktopId(value[key]))
            throw new Error("invalid identity override");
    }
    return JSON.parse(JSON.stringify(value));
}

function field(key, value) {
    if (key === "tilelanePins" || key === "tilelaneStartPins")
        return pins(value);
    if (key === "tilelaneIdentityOverrides")
        return overrides(value);
    if (key === "reducedMotion" && typeof value === "boolean")
        return value;
    throw new Error("invalid setting: " + key);
}

function read(bar) {
    const source = isObject(bar) ? bar : {};
    const result = { tilelanePins: [], tilelaneStartPins: [], tilelaneIdentityOverrides: {}, reducedMotion: false, errors: [] };
    const keys = ["tilelanePins", "tilelaneStartPins", "tilelaneIdentityOverrides", "reducedMotion"];
    for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        if (source[key] === undefined)
            continue;
        try {
            result[key] = field(key, source[key]);
        } catch (error) {
            result.errors.push(key + ": " + error);
        }
    }
    return result;
}

// Old pins can be discarded. Invalid pins must not prevent valid preferences
// from being preserved. Never write to the old file.
function legacyPreferences(text) {
    if (!String(text || "").trim())
        return { overrides: {}, reducedMotion: false };
    const old = JSON.parse(text);
    if (!isObject(old) || old.version !== 1)
        throw new Error("unsupported legacy settings format");
    if (old.reducedMotion !== undefined && typeof old.reducedMotion !== "boolean")
        throw new Error("invalid legacy reduced motion");
    return {
        overrides: old.overrides === undefined ? {} : overrides(old.overrides),
        reducedMotion: old.reducedMotion === true
    };
}

function initialize(bar, legacy) {
    if (bar.tilelaneSettingsVersion !== undefined)
        return false;
    if (bar.tilelanePins === undefined)
        bar.tilelanePins = [];
    if (bar.tilelaneStartPins === undefined)
        bar.tilelaneStartPins = [];
    if (bar.tilelaneIdentityOverrides === undefined)
        bar.tilelaneIdentityOverrides = legacy.overrides;
    if (bar.reducedMotion === undefined)
        bar.reducedMotion = legacy.reducedMotion;
    bar.tilelaneSettingsVersion = 1;
    return true;
}
