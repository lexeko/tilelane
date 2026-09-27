pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../HintLogic.js" as HintLogic
import qs.Commons as Commons

Rectangle {
    id: root

    required property string desktopId
    required property var applicationCatalog
    required property var pinnedApplications
    property var bar: null
    property real uiScale: 1
    property bool launching: false
    property bool controlOnPress: false
    readonly property int applicationIndexRevision: applicationCatalog ? applicationCatalog.indexRevision : 0
    readonly property var entry: {
        applicationIndexRevision;
        return applicationCatalog ? applicationCatalog.presentationForId(desktopId) : null;
    }
    readonly property string label: String(entry ? entry.name || desktopId : desktopId)
    readonly property string iconName: String(entry ? entry.icon || "" : "") || "application-x-executable"
    readonly property string iconSource: applicationCatalog.iconSource(iconName)
    readonly property bool tooltipHovered: pointer.containsMouse
    readonly property string hintText: HintLogic.application(label, bar ? bar.shortcut(label) : "")

    function px(value) {
        return value * uiScale;
    }

    function launch(floating) {
        if (!applicationCatalog.launch(desktopId, floating === true))
            return;
        launching = true;
        launchFeedback.restart();
    }

    function launchFromPointer(modifiers) {
        if (!applicationCatalog.launchFromPointer(desktopId, modifiers))
            return;
        launching = true;
        launchFeedback.restart();
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
            launchFromPointer(controlOnPress ? Qt.ControlModifier : Qt.NoModifier);
            controlOnPress = false;
            return true;
        }
        controlOnPress = false;
        return false;
    }

    width: px(32)
    height: px(32)
    radius: px(4)
    color: pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || contextMenu.open || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    border.color: Commons.Color.accent
    border.width: activeFocus ? Math.max(1, Math.round(px(1))) : 0
    opacity: entry ? 1 : 0.58
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: entry ? "Launch " + label : "Missing pinned application " + label
    Accessible.description: entry ? "Pinned application" : "Pinned application is unavailable"
    Accessible.onPressAction: launch()

    Component.onCompleted: {
        if (bar && typeof bar.registerClickTarget === "function")
            bar.registerClickTarget(root);
    }
    Component.onDestruction: {
        if (bar && typeof bar.unregisterClickTarget === "function")
            bar.unregisterClickTarget(root);
    }

    Image {
        id: iconImage

        anchors.centerIn: parent
        width: root.px(20)
        height: width
        source: root.iconSource
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        retainWhileLoading: true
    }

    Text {
        anchors.centerIn: parent
        visible: root.iconSource === "" || iconImage.status === Image.Error
        text: root.label.slice(0, 1).toUpperCase()
        color: Commons.Color.bar.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Commons.Util.alpha(Commons.Color.accent, 0.18)
        visible: root.launching

        SequentialAnimation on opacity {
            running: root.launching && !(root.bar && root.bar.reducedMotion === true)
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.4
                duration: 1100
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 1100
                easing.type: Easing.InOutSine
            }
        }
    }

    Timer {
        id: launchFeedback

        interval: 2200
        onTriggered: root.launching = false
    }

    Rectangle {
        visible: contextMenu.open
        width: Math.max(root.px(10), Math.round(parent.width * 0.55))
        height: root.px(2)
        radius: height / 2
        color: Commons.Color.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    TaskContextMenu {
        id: contextMenu

        anchorItem: root
        desktopId: root.desktopId
        launcherOnly: true
        applicationCatalog: root.applicationCatalog
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
        cursorShape: root.entry ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered: if (root.bar)
            root.bar.showTooltip(root, root.hintText, 550)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onPressed: function (event) {
            root.controlOnPress = event.button === Qt.LeftButton && (event.modifiers & Qt.ControlModifier) !== 0;
        }
        onCanceled: root.controlOnPress = false
        onClicked: function (event) {
            root.controlOnPress = root.controlOnPress || (event.modifiers & Qt.ControlModifier) !== 0;
            root.triggerPress(event.button);
        }
    }

    Keys.onSpacePressed: launch()
    Keys.onReturnPressed: launch()
    Keys.onEnterPressed: launch()
    Keys.onMenuPressed: contextMenu.open = !contextMenu.open
}
