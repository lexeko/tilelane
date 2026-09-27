pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../HintLogic.js" as HintLogic
import "../TaskLogic.js" as TaskLogic
import qs.Commons as Commons

Rectangle {
    id: root

    property string windowAddress: ""
    property string appId: "Application"
    property string desktopId: ""
    property string iconName: "application-x-executable"
    property string title: ""
    property bool windowActive: false
    property bool urgent: false
    property bool minimized: false
    property bool fullscreen: false
    property bool maximized: false
    property bool floating: false
    property bool launching: false
    property real uiScale: 1
    property real buttonHeight: 36
    property var actions: null
    property var applicationCatalog: null
    property var pinnedApplications: null
    property var bar: null
    readonly property string displayTitle: TaskLogic.displayTitle(title, appId)
    readonly property string iconSource: applicationCatalog ? applicationCatalog.iconSource(iconName) : Quickshell.iconPath(iconName, true)
    readonly property string visualState: TaskLogic.visualState(pointer.pressed, activeFocus, pointer.containsMouse || contextMenu.open, launching, urgent, windowActive, minimized)
    readonly property bool tooltipHovered: pointer.containsMouse
    readonly property string hintText: HintLogic.task(displayTitle)

    function px(value) {
        return value * uiScale;
    }

    function triggerPrimary() {
        if (actions)
            actions.toggle(windowAddress);
    }

    function triggerPress(button) {
        if (bar)
            bar.hideTooltip(root);
        if (button === Qt.RightButton) {
            contextMenu.open = !contextMenu.open;
            return true;
        }
        if (button === Qt.LeftButton) {
            if (bar && bar.activePopout && typeof bar.activePopout.close === "function")
                bar.activePopout.close();
            triggerPrimary();
            return true;
        }
        return false;
    }

    function openContextMenu() {
        contextMenu.open = true;
        return true;
    }

    implicitWidth: Math.min(px(224), Math.max(px(80), titleLabel.implicitWidth + px(64)))
    implicitHeight: buttonHeight
    radius: px(4)
    color: launching ? Commons.Style.normalFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : urgent ? Commons.Util.alpha(Commons.Color.urgent, 0.12) : windowActive ? Commons.Style.selectedAccentFill : minimized ? Commons.Util.alpha(Commons.Color.bar.text, 0.025) : Commons.Style.normalFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent)
    border.color: Commons.Color.accent
    border.width: activeFocus ? Math.max(1, Math.round(px(1))) : 0
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: displayTitle
    Accessible.description: minimized ? "Minimized window" : windowActive ? "Active window" : "Window"
    Accessible.onPressAction: triggerPrimary()

    Component.onCompleted: {
        if (bar && typeof bar.registerClickTarget === "function")
            bar.registerClickTarget(root);
    }
    Component.onDestruction: {
        if (bar && typeof bar.unregisterClickTarget === "function")
            bar.unregisterClickTarget(root);
    }

    Behavior on color {
        ColorAnimation {
            duration: root.bar && typeof root.bar.motionDuration === "function" ? root.bar.motionDuration(160) : 160
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || contextMenu.open || root.activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Commons.Util.alpha(Commons.Color.urgent, 0.12)
        visible: root.launching

        SequentialAnimation on opacity {
            running: root.launching && root.visible && !(root.bar && root.bar.reducedMotion === true)
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.35
                duration: 900
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    Item {
        id: iconBox

        width: root.px(20)
        height: root.px(20)
        anchors.left: parent.left
        anchors.leftMargin: root.px(7)
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: iconImage

            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.iconSource
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            retainWhileLoading: true
            opacity: root.minimized ? 0.55 : 1
        }

        Text {
            anchors.fill: parent
            visible: root.iconSource === "" || iconImage.status === Image.Error
            text: root.displayTitle.slice(0, 1).toUpperCase()
            color: Commons.Color.bar.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
        }
    }

    FontMetrics {
        id: titleMetrics

        font: titleLabel.font
    }

    Text {
        id: titleLabel

        anchors.left: iconBox.right
        anchors.leftMargin: root.px(7)
        anchors.right: parent.right
        anchors.rightMargin: root.px(8)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height / 2 - baselineOffset + titleMetrics.capitalHeight / 2
        color: Commons.Color.bar.text
        opacity: root.minimized ? 0.58 : root.windowActive ? 1 : 0.86
        text: root.displayTitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
    }

    Rectangle {
        visible: root.windowActive || contextMenu.open
        height: root.px(2)
        color: Commons.Color.accent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.px(5)
        anchors.rightMargin: root.px(5)
    }

    TaskContextMenu {
        id: contextMenu

        anchorItem: root
        address: root.windowAddress
        title: root.displayTitle
        minimized: root.minimized
        fullscreen: root.fullscreen
        maximized: root.maximized
        floating: root.floating
        actions: root.actions
        desktopId: root.desktopId
        pinnedApplications: root.pinnedApplications
        bar: root.bar
    }

    BarMouseArea {
        id: pointer

        bar: root.bar
        forwardPress: function (button) {
            return root.triggerPress(button);
        }

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: if (root.bar)
            root.bar.showTooltip(root, root.hintText, 550)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onClicked: function (event) {
            root.triggerPress(event.button);
        }
    }

    Keys.onSpacePressed: triggerPrimary()
    Keys.onReturnPressed: triggerPrimary()
    Keys.onEnterPressed: triggerPrimary()
    Keys.onMenuPressed: contextMenu.open = !contextMenu.open
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
            contextMenu.open = true;
            event.accepted = true;
        }
    }
}
