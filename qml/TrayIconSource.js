.pragma library

// Only installed theme icons may reach the shared shell's image decoder.
// Never forward application-controlled paths, fallback names, or opaque SNI
// handles: even a qsimage handle can load a file through a named overlay.
var fallbackName = "application-x-executable";

function themeSource(source) {
    const prefix = "image://icon/";
    if (typeof source !== "string" || source.length > 4096 || !source.startsWith(prefix))
        return prefix + fallbackName;

    const name = source.slice(prefix.length).split("?")[0];
    // No URL decoding: escaped separators, schemes, fragments, and filesystem
    // names must not acquire meaning in Qt or Quickshell after validation.
    if (name.length > 128 || !/^[A-Za-z0-9]/.test(name) || /[^A-Za-z0-9_.-]/.test(name))
        return prefix + fallbackName;

    return prefix + name + "?fallback=" + fallbackName;
}
