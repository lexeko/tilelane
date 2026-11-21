import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root

    readonly property string testDir: Quickshell.env("TILELANE_SUPER_START_TEST_DIR")
    property int triggers: 0
    property int actionId: 0

    readonly property string snapshot: JSON.stringify({
        enabled: controller.enabled,
        ready: controller.ready,
        hasApplied: controller.hasApplied,
        shuttingDown: controller.shuttingDown,
        triggers: triggers,
        actionId: actionId
    })

    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })

    SuperStartController {
        id: controller

        available: true
        onTriggered: root.triggers++
    }

    FileView {
        path: root.testDir + "/action.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const action = JSON.parse(text());
            if (action.id <= root.actionId)
                return;
            if (action.kind === "set")
                controller.enabled = action.value === true;
            else if (action.kind === "press" || action.kind === "release")
                controller.handleShortcutTriggered();
            else if (action.kind === "shutdown")
                controller.shutdown();
            root.actionId = action.id;
        }
    }

    FileView {
        id: output

        path: root.testDir + "/state.json"
        printErrors: false
    }
}
