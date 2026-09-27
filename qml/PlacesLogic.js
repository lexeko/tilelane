.pragma library

function decodeLabel(value) {
    try {
        return decodeURIComponent(String(value || ""));
    } catch (error) {
        return String(value || "");
    }
}

function directoryIcons(userDirsText, home) {
    const iconByKey = {
        "XDG_DOCUMENTS_DIR": "folder-documents-symbolic",
        "XDG_DOWNLOAD_DIR": "folder-download-symbolic",
        "XDG_MUSIC_DIR": "folder-music-symbolic",
        "XDG_PICTURES_DIR": "folder-pictures-symbolic",
        "XDG_PUBLICSHARE_DIR": "folder-publicshare-symbolic",
        "XDG_TEMPLATES_DIR": "folder-templates-symbolic",
        "XDG_VIDEOS_DIR": "folder-videos-symbolic"
    };
    const result = ({});
    const lines = String(userDirsText || "").split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const match = lines[index].match(/^\s*(XDG_[A-Z]+_DIR)\s*=\s*"([^"]*)"\s*$/);
        if (!match || !iconByKey[match[1]])
            continue;
        let path = match[2];
        if (path === "$HOME")
            path = home;
        else if (path.indexOf("$HOME/") === 0)
            path = home + "/" + path.slice(6);
        if (path && path !== home)
            result[path.replace(/\/$/, "")] = iconByKey[match[1]];
    }
    return result;
}

function filePath(uri) {
    const value = String(uri || "");
    if (value.indexOf("file://") !== 0)
        return "";
    let path = value.slice(7);
    if (path.indexOf("localhost/") === 0)
        path = path.slice(9);
    if (path.charAt(0) !== "/")
        return "";
    return decodeLabel(path).replace(/\/$/, "");
}

function fallbackName(uri) {
    const value = String(uri || "").replace(/\/$/, "");
    const slash = value.lastIndexOf("/");
    const candidate = slash >= 0 ? value.slice(slash + 1) : value;
    return decodeLabel(candidate) || value;
}

function parseBookmarks(text, userDirsText, home) {
    const result = [];
    const seen = ({});
    const icons = directoryIcons(userDirsText, home);
    const lines = String(text || "").split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index].trim();
        if (!line || line.charAt(0) === "#")
            continue;
        const separator = line.indexOf(" ");
        const uri = (separator < 0 ? line : line.slice(0, separator)).trim();
        if (!/^[A-Za-z][A-Za-z0-9+.-]*:\/\//.test(uri) || seen[uri])
            continue;
        seen[uri] = true;
        const label = separator < 0 ? fallbackName(uri) : line.slice(separator + 1).trim() || fallbackName(uri);
        const path = filePath(uri);
        result.push({
            "name": label,
            "uri": uri,
            "iconName": icons[path] || "folder-symbolic"
        });
    }
    return result;
}

function combined(primary, pinned) {
    const result = (primary || []).slice(0);
    if (pinned && pinned.length) {
        result.push({
            "divider": true
        });
        for (let index = 0; index < pinned.length; index++)
            result.push(pinned[index]);
    }
    return result;
}
