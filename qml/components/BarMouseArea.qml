pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    id: root

    property var bar: null
    property var forwardPress: null
    property real rightPadding: 0
    readonly property real bottomPadding: bar && parent ? Math.max(0, (bar.barHeight - parent.height) / 2) : 0
    readonly property var horizontalBounds: {
        if (!parent)
            return {
                left: 0,
                right: 0
            };
        let left = 0;
        let right = parent.width;
        let offset = 0;
        for (let item = parent; item; item = item.parent) {
            if (item !== parent && item.clip) {
                left = Math.max(left, -offset);
                right = Math.min(right, item.width - offset);
            }
            offset += item.x;
        }
        left = Math.max(0, Math.min(parent.width, left));
        return {
            left: left,
            right: Math.max(left, Math.min(parent.width, right))
        };
    }

    anchors.fill: parent
    anchors.leftMargin: horizontalBounds.left
    anchors.rightMargin: parent ? parent.width - horizontalBounds.right - rightPadding : 0
    anchors.bottomMargin: -bottomPadding

    function triggerPress(button) {
        if (!enabled || width <= 0 || !(acceptedButtons & button) || typeof forwardPress !== "function")
            return false;
        return forwardPress(button);
    }

    Component.onCompleted: if (bar)
        bar.registerClickTarget(root)
    Component.onDestruction: if (bar)
        bar.unregisterClickTarget(root)
}
