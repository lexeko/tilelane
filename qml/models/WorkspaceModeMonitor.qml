pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var workspaceIds: []
    property var pendingIds: []
    property int checkingId: 0
    property int generation: 0
    property int checkingGeneration: 0
    property int watchGeneration: 0
    property var modes: ({})
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
    readonly property string modesDir: stateHome + "/omarchy/workspace-layouts"
    property string defaultWatchPath: modesDir + "/default.lua"

    signal floating(int workspaceId)
    signal modeChecked(int workspaceId, string mode)

    function modeFor(workspaceId) {
        return String(modes[String(workspaceId)] || "");
    }

    function refresh() {
        generation++;
        modes = ({});
        const next = pendingIds.slice(0);
        for (const id of workspaceIds) {
            if (next.indexOf(id) === -1)
                next.push(id);
        }
        pendingIds = next;
        runNext();
    }

    function runNext() {
        if (modeProbe.running || pendingIds.length === 0)
            return;
        const next = pendingIds.slice(0);
        checkingId = next.shift();
        pendingIds = next;
        checkingGeneration = generation;
        modeProbe.command = ["omarchy-hyprland-workspace-layout-current", String(checkingId)];
        modeProbe.running = true;
    }

    function directoryChanged() {
        // A new mode file needs a new FileView. A watcher created before that
        // file existed cannot follow later writes to it.
        watchGeneration++;
        defaultWatchPath = "";
        Qt.callLater(() => defaultWatchPath = modesDir + "/default.lua");
        refresh();
    }

    onWorkspaceIdsChanged: refresh()

    property FileView directoryWatch: FileView {
        path: root.modesDir
        watchChanges: root.workspaceIds.length > 0
        printErrors: false
        onFileChanged: root.directoryChanged()
    }

    property FileView defaultFileWatch: FileView {
        path: root.defaultWatchPath
        watchChanges: root.workspaceIds.length > 0 && path !== ""
        printErrors: false
        onFileChanged: root.refresh()
    }

    property Instantiator workspaceFileWatches: Instantiator {
        model: root.workspaceIds.map(id => String(id) + ":" + root.watchGeneration)

        delegate: FileView {
            required property string modelData

            path: root.modesDir + "/" + modelData.split(":")[0] + ".lua"
            watchChanges: true
            printErrors: false
            onFileChanged: root.refresh()
        }
    }

    // Directory watches can go quiet after rapid changes. This runs only
    // while a Tilelane-owned window could move into Omarchy's dock.
    property Timer retry: Timer {
        interval: 15000
        repeat: true
        running: root.workspaceIds.length > 0
        onTriggered: root.refresh()
    }

    property Process modeProbe: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.checkingGeneration !== root.generation)
                    return;
                const mode = text.trim();
                const next = Object.assign({}, root.modes);
                next[String(root.checkingId)] = mode;
                root.modes = next;
                root.modeChecked(root.checkingId, mode);
                if (mode === "floating")
                    root.floating(root.checkingId);
            }
        }
        onExited: Qt.callLater(root.runNext)
    }
}
