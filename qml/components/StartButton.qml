pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Item {
    id: root

    signal clicked
    signal contextMenuRequested

    property var artwork: null
    property var bar: null
    property string label: "Start"
    property bool menuOpen: false
    property bool contextMenuOpen: false
    property real uiScale: 1
    property real leftHitPadding: 0
    property real bottomHitPadding: 0
    readonly property real visualHeight: px(36)
    readonly property real horizontalPadding: px(10)
    readonly property bool tooltipHovered: pointer.containsMouse && !menuOpen && !contextMenuOpen
    readonly property color textColor: Commons.Color.bar.text

    function px(value) {
        return value * uiScale;
    }

    implicitWidth: content.implicitWidth + horizontalPadding * 2 + leftHitPadding
    implicitHeight: visualHeight + bottomHitPadding
    activeFocusOnTab: true

    function triggerPress(button) {
        if (bar)
            bar.hideTooltip(root);
        if (button === Qt.RightButton) {
            contextMenuRequested();
            return true;
        }
        if (button === Qt.LeftButton) {
            clicked();
            return true;
        }
        return false;
    }

    Component.onCompleted: if (bar)
        bar.registerClickTarget(root)
    Component.onDestruction: if (bar)
        bar.unregisterClickTarget(root)

    Accessible.role: Accessible.Button
    Accessible.name: menuOpen ? "Close Start menu" : "Open applications"
    Accessible.onPressAction: clicked()

    Rectangle {
        id: buttonSurface

        x: root.leftHitPadding
        width: root.width - root.leftHitPadding
        height: root.visualHeight
        radius: root.px(4)
        color: root.menuOpen ? Commons.Style.selectedAccentFill : pointer.pressed ? Commons.Style.pressedFillFor(root.textColor, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || root.contextMenuOpen || root.activeFocus ? Commons.Util.alpha(root.textColor, 0.14) : Commons.Util.alpha(root.textColor, 0.09)
        border.color: root.activeFocus ? Commons.Color.accent : Commons.Util.alpha(root.textColor, 0.14)
        border.width: root.activeFocus ? Math.max(1, Math.round(root.px(1))) : 0

        Rectangle {
            visible: root.contextMenuOpen
            height: root.px(2)
            color: Commons.Color.accent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.px(5)
            anchors.rightMargin: root.px(5)
        }
    }

    Row {
        id: content

        anchors.fill: buttonSurface
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        spacing: root.px(7)

        BrandingLogo {
            width: root.px(20)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            artwork: root.artwork
            logoColor: root.textColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            textFormat: Text.PlainText
            color: root.textColor
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.subtitle
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.bar)
            root.bar.showTooltip(root, "Applications & places", 550)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onClicked: function (event) {
            root.triggerPress(event.button);
        }
    }

    onMenuOpenChanged: if (menuOpen && bar)
        bar.hideTooltip(root)
    onContextMenuOpenChanged: if (contextMenuOpen && bar)
        bar.hideTooltip(root)

    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onMenuPressed: contextMenuRequested()
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
            contextMenuRequested();
            event.accepted = true;
        }
    }
}
