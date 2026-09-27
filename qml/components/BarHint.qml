pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var barWindow
    property real uiScale: 1
    property Item target: null
    property string hintText: ""
    property bool requested: false
    property bool shown: false

    function owns(item) {
        return !!item && item.QsWindow.window === barWindow;
    }

    function eligible(item) {
        return owns(item) && item.visible !== false && item.opacity !== 0 && item.tooltipHovered === true;
    }

    function showFor(item, text, delay) {
        if (!eligible(item) || String(text || "").trim() === "")
            return false;
        target = item;
        hintText = String(text);
        requested = true;
        shown = false;
        showDelay.interval = delay === undefined ? 500 : Math.max(0, Number(delay));
        showDelay.restart();
        return true;
    }

    function hideFor(item) {
        if (item && target !== item)
            return false;
        clear();
        return true;
    }

    function clear() {
        showDelay.stop();
        requested = false;
        shown = false;
        target = null;
        hintText = "";
    }

    visible: shown && requested && target !== null && hintText !== "" && eligible(target)
    color: "transparent"
    implicitWidth: Math.ceil(bubble.implicitWidth)
    implicitHeight: Math.ceil(bubble.implicitHeight)
    mask: Region {}

    Timer {
        id: showDelay

        onTriggered: if (root.requested && root.target !== null && root.eligible(root.target))
            root.shown = true
    }

    anchor {
        id: hintAnchor

        window: root.barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
            if (!root.target || !root.barWindow)
                return;
            const localX = root.target.width / 2 - root.implicitWidth / 2;
            const localY = -root.implicitHeight - root.uiScale * 7;
            const point = root.barWindow.contentItem.mapFromItem(root.target, localX, localY);
            hintAnchor.rect.x = Math.round(point.x);
            hintAnchor.rect.y = Math.round(point.y);
        }
    }

    HintBubble {
        id: bubble

        text: root.hintText
        uiScale: root.uiScale
    }
}
