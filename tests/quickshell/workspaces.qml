import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root
    WorkspaceModel {
        id: workspaces
    }

    // Keep these as bindings, as in the real workspace switcher.
    readonly property var laptopIds: {
        workspaces.revision;
        return workspaces.idsForMonitor("eDP-1");
    }
    readonly property var externalIds: {
        workspaces.revision;
        return workspaces.idsForMonitor("DP-1");
    }

    IpcHandler {
        target: "test.workspaces"

        function state(): string {
            return JSON.stringify({
                laptop: root.laptopIds,
                external: root.externalIds,
                externalLabel: workspaces.labelForId(workspaces.activeIdForMonitor("DP-1")),
                externalBlock: workspaces.blockForMonitor("DP-1")
            });
        }

        function activate(id: string, monitor: string): bool {
            return workspaces.activate(Number(id), monitor);
        }
    }
}
