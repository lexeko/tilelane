pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property url directory
    readonly property Component nativeComponent: Qt.createComponent(Quickshell.shellPath("Commons/Translations.qml"), Component.PreferSynchronous)
    readonly property var nativeTranslator: nativeComponent.status === Component.Ready ? nativeComponent.createObject(root, {
        directory: Qt.binding(function () {
            return root.directory;
        })
    }) : null
    readonly property bool usingNative: nativeTranslator !== null && typeof nativeTranslator.t === "function"
    readonly property var englishStrings: {
        try {
            const parsed = JSON.parse(englishFile.text() || "{}");
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
        } catch (error) {
            return ({});
        }
    }

    function t(key, fallback) {
        if (usingNative)
            return nativeTranslator.t(key, fallback);
        const value = englishStrings[key];
        if (typeof value === "string" && value.length > 0)
            return value;
        return fallback !== undefined ? fallback : key;
    }

    property FileView englishFile: FileView {
        path: root.usingNative || String(root.directory) === "" ? "" : String(root.directory).replace(/^file:\/\//, "").replace(/\/+$/, "") + "/en.json"
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
    }
}
