import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property url directory
    readonly property string language: locale.text().trim()

    function t(key, fallback) {
        if (key === "tips.later")
            return language === "fr" ? "Plus tard" : "Native later";
        return fallback !== undefined ? fallback : key;
    }

    property FileView locale: FileView {
        path: String(root.directory).replace(/^file:\/\//, "") + "/language"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}
