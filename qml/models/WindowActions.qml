pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../TaskLogic.js" as TaskLogic

QtObject {
    id: root

    required property var windowModel
    property var fallbackOrigins: ({})
    property var observedOrigins: ({})
    property bool originsLoaded: false
    readonly property string originsPath: Quickshell.statePath("tilelane-minimized-v1.json")

    onFallbackOriginsChanged: rebuildModeCandidates()

    function activeDockCandidateIds() {
        const active = [];
        for (const monitor of Hyprland.monitors.values) {
            const workspace = monitor.activeWorkspace;
            if (workspace && TaskLogic.validWorkspaceId(workspace.id))
                active.push(String(workspace.id));
        }

        const ids = [];
        for (const address in fallbackOrigins) {
            const origin = String(fallbackOrigins[address]);
            if (active.indexOf(origin) === -1 || ids.indexOf(Number(origin)) !== -1)
                continue;
            const record = windowModel.recordFor(address);
            const source = windowModel.toplevelFor(address);
            if (record && record.workspaceName === TaskLogic.minimizedWorkspace && source && TaskLogic.canAppearInOmarchyDock(source.wayland))
                ids.push(Number(origin));
        }
        return ids.sort((first, second) => first - second);
    }

    function rebuildModeCandidates() {
        if (!windowModel || !modeMonitor)
            return;
        const ids = activeDockCandidateIds();
        if (JSON.stringify(ids) !== JSON.stringify(modeMonitor.workspaceIds))
            modeMonitor.workspaceIds = ids;
    }

    function migrateOwnedToDock(workspaceId) {
        for (const address in fallbackOrigins) {
            if (String(fallbackOrigins[address]) !== String(workspaceId))
                continue;
            const record = windowModel.recordFor(address);
            const source = windowModel.toplevelFor(address);
            if (!record || record.workspaceName !== TaskLogic.minimizedWorkspace || !source || !TaskLogic.canAppearInOmarchyDock(source.wayland))
                continue;
            const ipc = source.lastIpcObject || ({});
            const code = TaskLogic.dockMigrationCode(address, workspaceId, ipc.tags);
            if (code === "")
                continue;
            try {
                Hyprland.dispatch(TaskLogic.withoutCursorWarp(code));
            } catch (error) {
                Quickshell.execDetached(["hyprctl", "eval", "return hl.dispatch(" + TaskLogic.withoutCursorWarp(code) + ")"]);
            }
        }
    }

    function copyOrigins() {
        const result = ({});
        for (const address in fallbackOrigins)
            result[address] = fallbackOrigins[address];
        return result;
    }

    function rememberOrigin(address, workspaceName) {
        const normalized = String(address || "").toLowerCase();
        const workspace = String(workspaceName || "");
        if (!TaskLogic.validAddress(normalized) || workspace === "" || workspace === TaskLogic.minimizedWorkspace)
            return false;

        const next = copyOrigins();
        if (next[normalized] === undefined || observedOrigins[normalized] !== true)
            next[normalized] = workspace;
        fallbackOrigins = next;
        const seen = ({});
        for (const key in observedOrigins)
            seen[key] = observedOrigins[key];
        // The move is asynchronous. Ordinary window updates can arrive before
        // it reaches the hidden workspace; they must not look like a restore.
        seen[normalized] = false;
        observedOrigins = seen;
        persistOrigins();
        return true;
    }

    function forgetOrigin(address) {
        if (fallbackOrigins[address] === undefined)
            return;

        const next = copyOrigins();
        delete next[address];
        fallbackOrigins = next;
        const seen = ({});
        for (const key in observedOrigins) {
            if (key !== address)
                seen[key] = observedOrigins[key];
        }
        observedOrigins = seen;
        persistOrigins();
    }

    function persistOrigins() {
        if (originsLoaded)
            originsFile.setText(TaskLogic.serializeOrigins(fallbackOrigins));
    }

    function loadOrigins(text) {
        const saved = TaskLogic.parseOrigins(text);
        const merged = ({});
        for (const address in saved)
            merged[address] = saved[address];
        // A click can race the initial asynchronous read. The current session's
        // origin is authoritative when that happens.
        for (const address in fallbackOrigins)
            merged[address] = fallbackOrigins[address];
        fallbackOrigins = merged;
        originsLoaded = true;
        reconcileOrigins();
        persistOrigins();
    }

    function fallback(action, address, workspaceName) {
        const code = TaskLogic.fallbackCode(action, address, workspaceName);
        if (code === "")
            return false;

        Quickshell.execDetached(["hyprctl", "eval", "return hl.dispatch(" + TaskLogic.withoutCursorWarp(code) + ")"]);
        return true;
    }

    function activateExact(address, workspaceName) {
        const commands = TaskLogic.activationDispatches(address, workspaceName);
        if (commands.length === 0)
            return false;

        try {
            Hyprland.dispatch(TaskLogic.pointerStableDispatch(commands));
            return true;
        } catch (error) {
            return fallback("activate", address, "");
        }
    }

    function restoreExact(address, workspaceName) {
        const commands = TaskLogic.restoreDispatches(address, workspaceName);
        if (commands.length === 0)
            return false;

        try {
            Hyprland.dispatch(TaskLogic.pointerStableDispatch(commands));
            return true;
        } catch (error) {
            return fallback("restore", address, workspaceName);
        }
    }

    function invoke(address, action) {
        const record = windowModel.recordFor(address);
        const source = windowModel.toplevelFor(address);
        if (!record || !source)
            return false;

        if (action === "activate" && record.minimized)
            action = "restore";
        if (action === "activate")
            return activateExact(address, record.workspaceName || String(record.workspaceId || ""));

        if (action === "restore" && record.workspaceName === TaskLogic.omarchyMinimizedWorkspace) {
            const workspace = fallbackOrigins[address] || TaskLogic.restoreWorkspaceForMonitor(record.monitorName, Hyprland.monitors.values, Hyprland.focusedMonitor);
            return workspace !== "" && restoreExact(address, workspace);
        }

        const wayland = source.wayland || null;
        try {
            if (action === "close" && wayland) {
                wayland.close();
                return true;
            }
            if (action === "restore" && fallbackOrigins[address] === undefined && record.workspaceName !== TaskLogic.minimizedWorkspace && wayland) {
                wayland.minimized = false;
                return activateExact(address, record.workspaceName || String(record.workspaceId || ""));
            }
        } catch (error) {
            // A handle may disappear between the click and this call. The
            // exact-address fallback below is asynchronous and equally guarded.
        }

        if (action === "minimize") {
            if (TaskLogic.validAddress(address) && TaskLogic.canMinimizeToOmarchyDock(record, wayland)) {
                Quickshell.execDetached(["omarchy-hyprland-window-minimize", address]);
                return true;
            }
            if (!rememberOrigin(address, record.workspaceName || String(record.workspaceId || "")))
                return false;
            const queued = fallback("minimize", address, "");
            if (!queued)
                forgetOrigin(address);
            return queued;
        }
        if (action === "restore") {
            const origin = fallbackOrigins[address];
            return origin !== undefined && restoreExact(address, origin);
        }
        return fallback(action, address, "");
    }

    function toggle(address) {
        const record = windowModel.recordFor(address);
        if (!record)
            return false;
        return invoke(address, TaskLogic.primaryAction(record.active, record.minimized));
    }

    function reconcileOrigins() {
        if (!originsLoaded || !windowModel.initialized)
            return;

        const next = copyOrigins();
        const seen = ({});
        for (const address in observedOrigins)
            seen[address] = observedOrigins[address];
        let changed = false;
        let seenChanged = false;
        for (const address in next) {
            const record = windowModel.recordFor(address);
            const confirmedMinimized = record && (record.minimized || record.workspaceName === TaskLogic.minimizedWorkspace);
            if (confirmedMinimized && seen[address] !== true) {
                seen[address] = true;
                seenChanged = true;
            }
            if ((record && seen[address] === true && !record.minimized && record.workspaceName !== TaskLogic.minimizedWorkspace) || (!record && seen[address] === true)) {
                delete next[address];
                delete seen[address];
                changed = true;
                seenChanged = true;
            }
        }
        if (seenChanged)
            observedOrigins = seen;
        if (changed) {
            fallbackOrigins = next;
            persistOrigins();
        }
    }

    function restoreOwnedWindows() {
        for (const address in fallbackOrigins) {
            const record = windowModel.recordFor(address);
            if (record)
                fallback("restore", address, fallbackOrigins[address]);
        }
        fallbackOrigins = ({});
    }

    property FileView originsFile: FileView {
        path: root.originsPath
        atomicWrites: true
        printErrors: false

        onLoaded: root.loadOrigins(text())
        onLoadFailed: function (error) {
            root.loadOrigins("");
        }
    }

    property WorkspaceModeMonitor modeMonitor: WorkspaceModeMonitor {
        onFloating: function (workspaceId) {
            root.migrateOwnedToDock(workspaceId);
        }
    }

    property Timer modeCandidateDelay: Timer {
        interval: 100
        onTriggered: root.rebuildModeCandidates()
    }

    property Connections workspaceEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["workspace", "workspacev2", "focusedmon", "moveworkspace", "moveworkspacev2", "configreloaded"].indexOf(event.name) !== -1)
                root.modeCandidateDelay.restart();
        }
    }

    property Connections modelChanges: Connections {
        target: root.windowModel

        function onRevisionChanged() {
            root.reconcileOrigins();
            root.rebuildModeCandidates();
        }

        function onInitializedChanged() {
            root.reconcileOrigins();
            root.rebuildModeCandidates();
        }
    }

    Component.onCompleted: rebuildModeCandidates()
    Component.onDestruction: restoreOwnedWindows()
}
