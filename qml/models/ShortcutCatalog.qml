pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../HintLogic.js" as HintLogic

QtObject {
    id: root

    property var shortcuts: ({})
    property int revision: 0
    property bool refreshPending: false
    readonly property string userBindingsPath: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"

    function shortcut(description) {
        return String(shortcuts[String(description || "")] || "");
    }

    function refresh() {
        if (shortcutProbe.running) {
            refreshPending = true;
            return;
        }
        shortcutProbe.running = true;
    }

    property FileView userBindings: FileView {
        path: root.userBindingsPath
        watchChanges: true
        printErrors: false

        onFileChanged: root.refreshDebounce.restart()
    }

    property Timer refreshDebounce: Timer {
        interval: 200
        onTriggered: root.refresh()
    }

    property Process shortcutProbe: Process {
        command: ["omarchy", "menu", "keybindings", "--print"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.shortcuts = HintLogic.parseShortcuts(text);
                root.revision++;
            }
        }
        onExited: function () {
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refresh();
            }
        }
    }

    Component.onCompleted: refresh()
}
