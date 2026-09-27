import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root

    readonly property string testDir: Quickshell.env("TILELANE_SETTINGS_TEST_DIR")
    property var config: ({})
    property int writes: 0
    property int actionId: 0
    property bool actionResult: false
    readonly property string snapshot: JSON.stringify({
        loaded: settings.loaded,
        error: settings.lastError,
        values: settings.values,
        pins: pins.pins,
        startPins: startPins.pins,
        writes: writes,
        actionId: actionId,
        actionResult: actionResult
    })
    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })

    // Same synchronous snapshot and bar-only mutation contract as the host facade.
    QtObject {
        id: host
        function mutateShellConfig(mutator) {
            const copy = JSON.parse(JSON.stringify(root.config));
            const scoped = {
                bar: copy.bar
            };
            mutator(scoped);
            copy.bar = scoped.bar;
            root.config = copy;
            root.writes++;
            configFile.setText(JSON.stringify(copy));
            return true;
        }
    }

    TilelaneSettings {
        id: settings
        shell: host
        barConfig: root.config.bar || {}
        legacyPath: root.testDir + "/legacy.json"
    }

    PinnedApplications {
        id: pins
        settings: settings
    }

    PinnedApplications {
        id: startPins
        settings: settings
        settingsKey: "tilelaneStartPins"
    }

    FileView {
        id: configFile
        path: root.testDir + "/shell.json"
        watchChanges: true
        atomicWrites: true
        onLoaded: root.config = JSON.parse(text())
        onFileChanged: reload()
    }

    FileView {
        path: root.testDir + "/action.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const action = JSON.parse(text());
            if (action.id <= root.actionId)
                return;
            if (action.kind === "pin")
                root.actionResult = pins.pin(action.value);
            else if (action.kind === "startPin")
                root.actionResult = startPins.pin(action.value);
            else if (action.kind === "move")
                root.actionResult = pins.move(action.value, action.offset);
            else if (action.kind === "unpin")
                root.actionResult = pins.unpin(action.value);
            else
                root.actionResult = settings.setValue(action.key, action.value);
            root.actionId = action.id;
        }
    }

    FileView {
        id: output
        path: root.testDir + "/state.json"
        printErrors: false
    }
}
