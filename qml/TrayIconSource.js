.pragma library

// Only installed theme icons may reach the shared shell's image decoder.
// Never forward application-controlled paths, fallback names, or opaque SNI
// handles: even a qsimage handle can load a file through a named overlay.
var fallbackName = "application-x-executable";

function fallbackSource(itemId) {
    // Roam's SNI IconName property fails, but its package installs this theme
    // icon. Use the fixed installed name instead of decoding its SNI pixmap.
    if (/^Roam_status_icon_[0-9]{1,6}$/.test(String(itemId || "")))
        return "image://icon/roam?fallback=" + fallbackName;
    return "image://icon/" + fallbackName;
}

function themeSource(source, itemId) {
    const prefix = "image://icon/";
    if (typeof source !== "string" || source.length > 4096 || !source.startsWith(prefix))
        return fallbackSource(itemId);

    const name = source.slice(prefix.length).split("?")[0];
    // No URL decoding: escaped separators, schemes, fragments, and filesystem
    // names must not acquire meaning in Qt or Quickshell after validation.
    if (name.length > 128 || !/^[A-Za-z0-9]/.test(name) || /[^A-Za-z0-9_.-]/.test(name))
        return fallbackSource(itemId);

    return prefix + name + "?fallback=" + fallbackName;
}
