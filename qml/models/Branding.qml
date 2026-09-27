import QtQuick
import Quickshell
import Quickshell.Io
import "../BrandingArt.js" as BrandingArt

Item {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/branding/about.txt"
    property var artwork: null
    property bool loaded: false
    visible: false

    function applyText(raw) {
        artwork = BrandingArt.parse(raw);
        loaded = true;
    }

    property FileView brandingFile: FileView {
        path: root.path
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: {
            root.artwork = null;
            root.loaded = true;
        }
    }
}
