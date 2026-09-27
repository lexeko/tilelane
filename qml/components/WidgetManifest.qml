pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../StatusWidgetLogic.js" as StatusWidgetLogic

Item {
    id: root

    property string sourceDir: ""
    property string entryPoint: ""
    visible: false
    onSourceDirChanged: entryPoint = ""

    FileView {
        path: root.sourceDir !== "" ? root.sourceDir + "/manifest.json" : ""
        watchChanges: path !== ""
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.entryPoint = StatusWidgetLogic.manifestEntryPoint(text())
        onLoadFailed: root.entryPoint = ""
    }
}
