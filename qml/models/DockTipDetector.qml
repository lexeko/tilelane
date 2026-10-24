pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../TipLogic.js" as TipLogic

QtObject {
    id: root

    property string barPosition: "bottom"
    property var shellConfig: null
    property bool dockEnabled: false
    property bool pluginRefreshPending: false
    readonly property string configBase: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property var dockConfig: shellConfig && shellConfig.dock && typeof shellConfig.dock === "object" ? shellConfig.dock : ({})
    readonly property string dockPosition: ["top", "bottom", "left", "right"].indexOf(dockConfig.position) >= 0 ? dockConfig.position : "bottom"
    readonly property bool dockAutohide: dockConfig.autohide === true
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property string screenName: focusedMonitor ? String(focusedMonitor.name || "") : ""
    readonly property int workspaceId: focusedMonitor && focusedMonitor.activeWorkspace ? Number(focusedMonitor.activeWorkspace.id || 0) : 0
    readonly property string workspaceMode: modeMonitor.modeFor(workspaceId)
    readonly property int fullscreenMode: {
        let mode = 0;
        for (const window of Hyprland.toplevels.values || []) {
            if (!window.workspace || window.workspace.id !== workspaceId)
                continue;
            const ipc = window.lastIpcObject || ({});
            mode = Math.max(mode, Number(ipc.fullscreen || 0));
        }
        return mode;
    }
    readonly property bool conflict: shellConfig !== null && TipLogic.dockOverlap({
        dockEnabled: dockEnabled,
        dockPosition: dockPosition,
        dockAutohide: dockAutohide,
        barPosition: barPosition,
        workspaceMode: workspaceMode,
        fullscreenMode: fullscreenMode,
        screenName: screenName
    })

    function refreshPlugins() {
        if (pluginProbe.running) {
            pluginRefreshPending = true;
            return;
        }
        pluginProbe.running = true;
    }

    property FileView configFile: FileView {
        path: root.configBase + "/omarchy/shell.json"
        watchChanges: true
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.shellConfig = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null;
            } catch (error) {
                root.shellConfig = null;
            }
            root.refreshPlugins();
        }
        onFileChanged: reload()
        onLoadFailed: root.shellConfig = null
    }

    property WorkspaceModeMonitor modeMonitor: WorkspaceModeMonitor {
        workspaceIds: root.workspaceId > 0 ? [root.workspaceId] : []
    }

    property Process pluginProbe: Process {
        command: ["omarchy", "plugin", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let enabled = false;
                try {
                    const entries = JSON.parse(text);
                    enabled = Array.isArray(entries) && entries.some(entry => entry && entry.id === "omarchy.dock" && entry.enabled === true);
                } catch (error) {}
                root.dockEnabled = enabled;
            }
        }
        onExited: {
            if (root.pluginRefreshPending) {
                root.pluginRefreshPending = false;
                root.refreshPlugins();
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event && event.name === "fullscreen")
                Hyprland.refreshToplevels();
        }
    }

    Component.onCompleted: refreshPlugins()
}
