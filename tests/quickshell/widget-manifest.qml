import QtQuick
import Quickshell
import Quickshell.Io
import "qml/components"

ShellRoot {
    id: root

    readonly property string testDir: Quickshell.env("TILELANE_WIDGET_TEST_DIR")
    readonly property string snapshot: JSON.stringify({
        available: host.available,
        entryPoint: host.manifestEntryPoint,
        label: host.hostItem ? host.hostItem.label : "",
        moduleName: host.hostItem ? host.hostItem.moduleName : "",
        setting: host.hostItem ? host.hostItem.settings.label || "" : ""
    })

    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })
    Component.onCompleted: output.setText(snapshot)

    HostedBarWidget {
        id: host
        moduleName: "test.manifest"
        registry: ({
                widgets: {
                    "test.manifest": {
                        metadata: {
                            sourceDir: root.testDir + "/plugin"
                        }
                    }
                }
            })
        settings: ({
                label: "Injected"
            })
    }

    FileView {
        id: output
        path: root.testDir + "/state.json"
        printErrors: false
    }
}
