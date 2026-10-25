import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root
    readonly property string snapshot: JSON.stringify({
        checked: capabilities.checked,
        layout: capabilities.workspaceLayout,
        minimize: capabilities.nativeMinimize,
        active: monitor.active,
        mode: monitor.modeFor(2),
        retry: monitor.retry.running,
        directoryWatch: monitor.directoryWatch.path,
        watchCount: monitor.workspaceFileWatches.count
    })
    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })
    Component.onCompleted: output.setText(snapshot)

    OmarchyCapabilities {
        id: capabilities
    }
    WorkspaceModeMonitor {
        id: monitor
        available: capabilities.workspaceLayout
        workspaceIds: [2]
    }
    FileView {
        id: output
        path: Quickshell.shellPath("state.json")
        printErrors: false
    }
}
