pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Rectangle {
    id: root

    signal clicked

    required property real buttonHeight
    property bool pointsLeft: false
    property string hintText: ""
    property var bar: null
    property real uiScale: 1
    readonly property bool tooltipHovered: pointer.containsMouse && enabled

    function px(value) {
        return value * uiScale;
    }

    implicitWidth: Math.ceil(glyphIcon.controlGlyphWidth + px(16))
    implicitHeight: buttonHeight
    width: implicitWidth
    height: implicitHeight
    radius: px(4)
    color: pointer.containsMouse && enabled ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    opacity: enabled ? 1 : 0.3
    activeFocusOnTab: enabled

    Accessible.role: Accessible.Button
    Accessible.name: hintText
    Accessible.onPressAction: if (enabled)
        clicked()

    OverflowIcon {
        id: glyphIcon

        anchors.centerIn: parent
        pointsLeft: root.pointsLeft
        color: Commons.Color.bar.text
    }

    BarMouseArea {
        id: pointer

        bar: root.bar
        forwardPress: function (button) {
            if (button !== Qt.LeftButton)
                return false;
            root.clicked();
            return true;
        }

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: if (root.bar)
            root.bar.showTooltip(root, root.hintText, 450)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onClicked: {
            if (root.bar)
                root.bar.hideTooltip(root);
            root.clicked();
        }
    }

    Keys.onSpacePressed: if (enabled)
        clicked()
    Keys.onReturnPressed: if (enabled)
        clicked()
    Keys.onEnterPressed: if (enabled)
        clicked()
}
