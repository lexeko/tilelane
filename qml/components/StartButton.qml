pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Item {
    id: root

    signal clicked

    property var artwork: null
    property var bar: null
    property string label: "Start"
    property bool menuOpen: false
    property real uiScale: 1
    property real leftHitPadding: 0
    property real bottomHitPadding: 0
    readonly property real visualHeight: px(36)
    readonly property bool tooltipHovered: pointer.containsMouse && !menuOpen
    readonly property color textColor: Commons.Color.bar.text

    function px(value) {
        return value * uiScale;
    }

    implicitWidth: Math.max(px(90), content.implicitWidth + px(20)) + leftHitPadding
    implicitHeight: visualHeight + bottomHitPadding
    activeFocusOnTab: true

    function triggerPress(button) {
        if (button !== Qt.LeftButton)
            return false;
        if (bar)
            bar.hideTooltip(root);
        clicked();
        return true;
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
        color: root.menuOpen ? Commons.Style.selectedAccentFill : pointer.pressed ? Commons.Style.pressedFillFor(root.textColor, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || root.activeFocus ? Commons.Util.alpha(root.textColor, 0.14) : Commons.Util.alpha(root.textColor, 0.09)
        border.color: root.activeFocus ? Commons.Color.accent : Commons.Util.alpha(root.textColor, 0.14)
        border.width: root.activeFocus ? Math.max(1, Math.round(root.px(1))) : 0
    }

    Row {
        id: content

        anchors.fill: buttonSurface
        anchors.leftMargin: root.px(10)
        anchors.rightMargin: root.px(10)
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
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.bar)
            root.bar.showTooltip(root, "Applications & places", 550)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onClicked: root.triggerPress(Qt.LeftButton)
    }

    onMenuOpenChanged: if (menuOpen && bar)
        bar.hideTooltip(root)

    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
