import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root

    readonly property string testDir: Quickshell.env("TILELANE_HIDES_TEST_DIR")
    readonly property string snapshot: JSON.stringify({
        "listed": catalog.search("").map(entry => entry.id).sort(),
        "hidden": Object.keys(catalog.configuredHiddenEntryIds).sort()
    })

    onSnapshotChanged: Qt.callLater(() => output.setText(root.snapshot))
    Component.onCompleted: output.setText(snapshot)

    ApplicationCatalog {
        id: catalog
        omarchyPath: root.testDir
    }

    FileView {
        id: output
        path: root.testDir + "/state.json"
        atomicWrites: true
        printErrors: false
    }
}
