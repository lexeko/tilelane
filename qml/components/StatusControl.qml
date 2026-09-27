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
    readonly property bool tooltipHovered: hover.hovered && hover.point.position.x >= pointer.x && hover.point.position.x < pointer.x + pointer.width && hover.point.position.y >= pointer.y && hover.point.position.y < pointer.y + pointer.height
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

    function syncHint() {
        if (!bar)
            return;
        if (tooltipHovered && hintText !== "")
            bar.showTooltip(root, hintText);
        else
            bar.hideTooltip(root);
    }

    // MouseArea.entered can run before HoverHandler updates tooltipHovered.
    // Request hints from the same state that the tooltip host validates.
    onTooltipHoveredChanged: syncHint()
    onHintTextChanged: syncHint()

    implicitWidth: px(30)
    implicitHeight: px(32)
    width: implicitWidth
    height: implicitHeight
    radius: px(4)
    border.width: 0
    color: pointer.pressed ? pressedColor : tooltipHovered || activeFocus ? hoverColor : "transparent"
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

    // Observe as an ancestor of native input handlers, not a covering sibling.
    // Margin reaches the edges; tooltipHovered clips it to the actual hit area.
    HoverHandler {
        id: hover
        margin: Math.max(root.rightHitPadding, pointer.bottomPadding)
        blocking: false
    }

    BarMouseArea {
        id: pointer

        z: root.nativeInput ? -1 : 10
        bar: root.bar
        rightPadding: root.rightHitPadding
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        forwardPress: function (button) {
            return root.activate(button);
        }
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
