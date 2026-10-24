pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../TipLogic.js" as TipLogic

QtObject {
    id: root

    required property var settings
    property var bar: null
    property string barPosition: "bottom"
    property var hiddenThisSession: []
    property bool stableDockConflict: false
    property string saveError: ""
    readonly property string screenName: dockDetector.screenName
    readonly property var tips: [
        {
            id: "dock-overlap",
            buttonKey: "tips.dock.button",
            titleKey: "tips.dock.title",
            bodyKey: "tips.dock.body",
            actionKey: "tips.dock.action",
            eligible: stableDockConflict
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
            saveError = "Could not save this preference.";
            return false;
        }
        saveError = "";
        later(id);
        return true;
    }

    function runAction(id) {
        if (id === "dock-overlap") {
            Quickshell.execDetached(["omarchy", "menu", "summon", "trigger.appearance.dock"]);
            return true;
        }
        return false;
    }

    onSaveErrorChanged: if (saveError)
        console.warn("Tilelane tip: " + saveError)

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
