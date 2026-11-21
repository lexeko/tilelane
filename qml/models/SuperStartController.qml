pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../SuperStartLogic.js" as SuperStartLogic

QtObject {
    id: root

    signal triggered

    property bool enabled: false
    property bool available: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    property bool ready: false
    property bool hasApplied: false
    property bool syncPending: false
    property bool shuttingDown: false
    property bool lastRequestedState: false
    property bool hasSynced: false

    function sync(force) {
        if (!available || shuttingDown)
            return false;
        const desired = enabled === true;
        if (!force && hasSynced && lastRequestedState === desired && !syncProcess.running)
            return false;
        if (syncProcess.running) {
            syncPending = true;
            return true;
        }
        lastRequestedState = desired;
        hasSynced = true;
        if (desired)
            hasApplied = true;
        syncProcess.command = ["hyprctl", "eval", SuperStartLogic.syncLua(desired)];
        syncProcess.running = true;
        return true;
    }

    function shutdown() {
        if (shuttingDown)
            return;
        shuttingDown = true;
        initTimer.stop();
        reloadTimer.stop();
        if (!available || !(enabled || hasApplied))
            return;
        Quickshell.execDetached(["hyprctl", "eval", SuperStartLogic.disableLua()]);
    }

    function handleShortcutTriggered() {
        if (enabled && !shuttingDown)
            triggered();
    }

    onEnabledChanged: {
        if (ready)
            sync(false);
    }

    property GlobalShortcut shortcut: GlobalShortcut {
        appid: SuperStartLogic.shortcutAppId
        name: SuperStartLogic.shortcutName
        description: "Toggle Tilelane Start menu"
        onPressed: root.handleShortcutTriggered()
        onReleased: root.handleShortcutTriggered()
    }

    property Process syncProcess: Process {
        onExited: function () {
            if (root.shuttingDown)
                return;
            if (root.syncPending) {
                root.syncPending = false;
                root.sync(true);
            }
        }
    }

    property Timer initTimer: Timer {
        interval: 50
        onTriggered: {
            root.ready = true;
            root.sync(true);
        }
    }

    property Timer reloadTimer: Timer {
        interval: 150
        onTriggered: {
            if (root.enabled && !root.shuttingDown)
                root.sync(true);
        }
    }

    property Connections hyprlandEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (SuperStartLogic.shouldHandleReload(event.name, root.enabled))
                root.reloadTimer.restart();
        }
    }

    Component.onCompleted: {
        if (available)
            initTimer.restart();
    }
    Component.onDestruction: shutdown()
}
