pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../TipLogic.js" as TipLogic

QtObject {
    id: root

    required property var settings
    property var bar: null
    property string barPosition: "bottom"
    property var hiddenThisSession: []
    property bool stableDockConflict: false
    property bool actionPending: false
    property bool actionFailed: false
    property string errorKey: ""
    property var pendingCommands: []
    property int commandIndex: 0
    readonly property string screenName: dockDetector.screenName
    readonly property var tips: [
        {
            id: "dock-overlap",
            buttonKey: "tips.dock.button",
            titleKey: "tips.dock.title",
            bodyKey: "tips.dock.body",
            titleIcon: "dock-grid",
            actions: [
                {
                    id: "left",
                    labelKey: "tips.dock.left",
                    glyph: "←"
                },
                {
                    id: "top",
                    labelKey: "tips.dock.top",
                    glyph: "↑"
                },
                {
                    id: "right",
                    labelKey: "tips.dock.right",
                    glyph: "→"
                }
            ],
            eligible: stableDockConflict || actionPending || actionFailed
        }
    ]
    readonly property var currentTip: TipLogic.select(tips, settings.values.tilelaneDismissedTips, hiddenThisSession)

    function later(id) {
        if (!id || hiddenThisSession.indexOf(id) >= 0)
            return;
        hiddenThisSession = hiddenThisSession.concat([id]);
    }

    function dismiss(id) {
        if (!id || !currentTip || currentTip.id !== id)
            return false;
        const next = settings.values.tilelaneDismissedTips.concat([id]);
        if (!settings.setValue("tilelaneDismissedTips", next)) {
            errorKey = "tips.saveError";
            return false;
        }
        errorKey = "";
        later(id);
        return true;
    }

    function runAction(id, choice) {
        if (id !== "dock-overlap" || actionPending)
            return false;
        const commands = TipLogic.dockActionCommands(choice);
        if (commands.length !== 2)
            return false;
        errorKey = "";
        actionFailed = false;
        pendingCommands = commands;
        commandIndex = 0;
        actionPending = true;
        dockAction.command = commands[0];
        dockAction.running = true;
        return true;
    }

    onErrorKeyChanged: if (errorKey)
        console.warn("Tilelane tip: " + errorKey)

    property Process dockAction: Process {
        onExited: function (exitCode) {
            if (!root.actionPending)
                return;
            if (exitCode !== 0) {
                root.actionPending = false;
                root.actionFailed = true;
                root.errorKey = "tips.dock.error";
                return;
            }
            if (root.commandIndex + 1 < root.pendingCommands.length) {
                root.commandIndex++;
                Qt.callLater(() => {
                    dockAction.command = root.pendingCommands[root.commandIndex];
                    dockAction.running = true;
                });
                return;
            }
            root.actionPending = false;
            root.actionFailed = false;
            root.pendingCommands = [];
            root.later("dock-overlap");
        }
    }

    property DockTipDetector dockDetector: DockTipDetector {
        barPosition: root.barPosition

        onConflictChanged: {
            root.stableDockConflict = false;
            if (conflict)
                stableDelay.restart();
            else
                stableDelay.stop();
        }
    }

    property Timer stableDelay: Timer {
        interval: 1500
        onTriggered: root.stableDockConflict = dockDetector.conflict
    }
}
