pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../WorkspaceLogic.js" as WorkspaceLogic

Item {
    id: root

    property alias model: workspaces
    property int defaultCount: 5
    property int revision: 0
    property var blocks: ({})
    readonly property int focusedId: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id || 0) : 0

    function sourceValues() {
        return Hyprland.workspaces.values || [];
    }

    function activeIdForMonitor(monitorName) {
        return WorkspaceLogic.activeIdForMonitor(sourceValues(), monitorName);
    }

    function blockForMonitor(monitorName) {
        return WorkspaceLogic.monitorBlock(blocks, sourceValues(), monitorName);
    }

    function idsForMonitor(monitorName) {
        return WorkspaceLogic.monitorWorkspaceIds(sourceValues(), defaultCount, blockForMonitor(monitorName), monitorName);
    }

    function labelForId(id) {
        return WorkspaceLogic.label(id);
    }

    function indexForId(id) {
        for (let index = 0; index < workspaces.count; index++) {
            if (workspaces.get(index).id === Number(id))
                return index;
        }
        return -1;
    }

    function recordFor(id) {
        const index = indexForId(id);
        return index === -1 ? null : workspaces.get(index);
    }

    function ids() {
        const result = [];
        for (let index = 0; index < workspaces.count; index++)
            result.push(workspaces.get(index).id);
        return result;
    }

    function rebuild() {
        const desired = WorkspaceLogic.records(sourceValues(), focusedId, defaultCount);
        let changed = workspaces.count !== desired.length;
        for (let index = 0; index < desired.length; index++) {
            if (index >= workspaces.count) {
                workspaces.append(desired[index]);
                changed = true;
            } else if (!WorkspaceLogic.sameRecord(workspaces.get(index), desired[index])) {
                workspaces.set(index, desired[index]);
                changed = true;
            }
        }
        while (workspaces.count > desired.length)
            workspaces.remove(workspaces.count - 1);
        if (changed)
            revision++;
    }

    function activate(id, monitorName) {
        const target = WorkspaceLogic.validId(id);
        const monitor = monitorName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
        if (target === 0 || idsForMonitor(monitor).indexOf(target) === -1)
            return false;
        try {
            Hyprland.dispatch(WorkspaceLogic.focusCommand(target, blockForMonitor(monitor), monitor));
            return true;
        } catch (error) {
            console.warn("Tilelane could not activate workspace " + target + ": " + error);
            return false;
        }
    }

    visible: false
    onFocusedIdChanged: rebuild()
    Component.onCompleted: rebuild()

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.blocks = WorkspaceLogic.parseBlocks(text())
        onLoadFailed: root.blocks = ({})
    }

    ListModel {
        id: workspaces

        dynamicRoles: true
    }

    Timer {
        id: monitorRefresh

        interval: 25
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // A workspace move emits intermediate focus events before the
            // final monitor assignments. Quickshell can retain that earlier
            // active workspace, so refresh once after the move event burst.
            if (["moveworkspace", "moveworkspacev2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].indexOf(event.name) !== -1)
                monitorRefresh.restart();
        }
    }

    Connections {
        target: Hyprland.workspaces

        function onValuesChanged() {
            root.rebuild();
        }
    }

    Instantiator {
        model: Hyprland.workspaces

        delegate: Item {
            id: tracker

            required property var modelData
            visible: false
            Component.onCompleted: root.rebuild()
            Component.onDestruction: root.rebuild()

            Connections {
                target: tracker.modelData
                ignoreUnknownSignals: true

                function onIdChanged() {
                    root.rebuild();
                }

                function onNameChanged() {
                    root.rebuild();
                }

                function onActiveChanged() {
                    root.rebuild();
                }

                function onFocusedChanged() {
                    root.rebuild();
                }

                function onUrgentChanged() {
                    root.rebuild();
                }

                function onHasFullscreenChanged() {
                    root.rebuild();
                }

                function onMonitorChanged() {
                    root.rebuild();
                }
            }

            Connections {
                target: tracker.modelData ? tracker.modelData.toplevels : null
                ignoreUnknownSignals: true

                function onValuesChanged() {
                    root.rebuild();
                }
            }
        }
    }
}
