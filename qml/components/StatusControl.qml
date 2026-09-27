pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: root

    property var bar: null
    property real uiScale: 1
    property real rightHitPadding: 0
    property string hintText: ""
    property string accessibleName: hintText
    property string accessibleDescription: ""
    property bool opened: false
    // Native components keep their own pointer/wheel handlers. The common
    // control remains behind them for keyboard and bottom-edge activation.
    property bool nativeInput: false
    property var activation: null
    property int pressActionButtons: 0
    property var wheelAction: null
    property real indicatorWidth: Math.max(px(10), Math.round(width * 0.55))
    readonly property bool tooltipHovered: hover.hovered
    readonly property bool indicatorVisible: opened || activeFocus
    readonly property alias clickTarget: pointer
    property color accentColor: bar && bar.accentColor !== undefined ? bar.accentColor : "white"
    property color hoverColor: bar && bar.statusHoverFill !== undefined ? bar.statusHoverFill : "transparent"
    property color pressedColor: bar && bar.statusPressedFill !== undefined ? bar.statusPressedFill : "transparent"

    function px(value) {
        return value * uiScale;
    }

    function activate(button) {
        if (bar)
            bar.hideTooltip(root);
        return typeof activation === "function" && activation(button) === true;
    }

    implicitWidth: px(30)
    implicitHeight: px(32)
    width: implicitWidth
    height: implicitHeight
    radius: px(4)
    border.width: 0
    color: pointer.pressed ? pressedColor : hover.hovered || activeFocus ? hoverColor : "transparent"
    activeFocusOnTab: visible && enabled

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription
    Accessible.onPressAction: activate(Qt.LeftButton)

    Rectangle {
        z: 100
        visible: root.indicatorVisible
        width: root.indicatorWidth
        height: root.px(2)
        radius: height / 2
        color: root.accentColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    BarMouseArea {
        id: pointer

        // Match hover feedback to the full hit area, including screen edges.
        // A handler still observes native widgets that own their mouse input.
        HoverHandler {
            id: hover
        }

        z: root.nativeInput ? -1 : 10
        bar: root.bar
        rightPadding: root.rightHitPadding
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        forwardPress: function (button) {
            return root.activate(button);
        }
        onEntered: if (root.bar && root.hintText !== "")
            root.bar.showTooltip(root, root.hintText)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onPressed: function (event) {
            if (root.pressActionButtons & event.button)
                root.activate(event.button);
        }
        onClicked: function (event) {
            if (!(root.pressActionButtons & event.button))
                root.activate(event.button);
        }
        onWheel: function (event) {
            if (typeof root.wheelAction === "function")
                root.wheelAction(event);
            else
                event.accepted = false;
        }
    }

    Keys.onSpacePressed: activate(Qt.LeftButton)
    Keys.onReturnPressed: activate(Qt.LeftButton)
    Keys.onEnterPressed: activate(Qt.LeftButton)
}
