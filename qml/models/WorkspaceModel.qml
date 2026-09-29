pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../WorkspaceLogic.js" as WorkspaceLogic

Item {
    id: root

    property alias model: workspaces
    property int defaultCount: 5
    property int revision: 0
    readonly property int focusedId: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id || 0) : 0

    function sourceValues() {
        return Hyprland.workspaces.values || [];
    }

    function activeIdForMonitor(monitorName) {
        return WorkspaceLogic.activeIdForMonitor(sourceValues(), monitorName);
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

    function activate(id) {
        const target = WorkspaceLogic.validId(id);
        if (target === 0)
            return false;
        try {
            // Hyprland 0.56's dispatcher accepts typed Lua expressions. The
            // Quickshell workspace activate() helper still emits the retired
            // `workspace N` grammar, so use the same direct compositor socket
            // with a validated numeric target instead.
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + target + '" })');
            return true;
        } catch (error) {
            console.warn("Tilelane could not activate workspace " + target + ": " + error);
            return false;
        }
    }

    visible: false
    onFocusedIdChanged: rebuild()
    Component.onCompleted: rebuild()

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
            if (event.name === "moveworkspace" || event.name === "moveworkspacev2")
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
