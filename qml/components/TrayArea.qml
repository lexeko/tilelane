pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import "../HintLogic.js" as HintLogic
import "../StatusLogic.js" as StatusLogic
import qs.Commons as Commons

Item {
    id: root

    property var bar: null
    property var excludedItemNames: []
    property real uiScale: 1
    property bool expanded: false
    property var activeMenu: null
    property real maximumDrawerExtent: Number.POSITIVE_INFINITY
    property int sourceRevision: 0
    readonly property var sourceItems: {
        sourceRevision;
        return SystemTray.items.values || [];
    }
    readonly property var activeItems: {
        return StatusLogic.activeTrayItems(sourceItems, Status.Passive, excludedItemNames);
    }
    readonly property int itemCount: activeItems.length
    readonly property real itemGap: px(1)
    readonly property real slotWidth: px(30)
    readonly property real hitSize: px(32)
    readonly property real bottomHitPadding: bar ? Math.max(0, (bar.barHeight - hitSize) / 2) : 0
    readonly property real drawerExtent: itemCount > 0 ? itemCount * slotWidth + (itemCount - 1) * itemGap : 0
    property real revealProgress: expanded ? 1 : 0
    readonly property real revealExtent: Math.min(drawerExtent, maximumDrawerExtent) * revealProgress

    function px(value) {
        return value * uiScale;
    }

    function toggle() {
        openTimer.stop();
        collapseTimer.stop();
        if (expanded && activeMenu)
            activeMenu.close();
        expanded = !expanded;
    }

    function openFirstMenu() {
        openTimer.stop();
        collapseTimer.stop();
        expanded = true;
        for (let index = 0; index < trayRepeater.count; index++) {
            const item = trayRepeater.itemAt(index);
            if (item && item.openContextMenu())
                return true;
        }
        return false;
    }

    visible: itemCount > 0
    implicitWidth: visible ? expandButton.width + revealExtent : 0
    implicitHeight: hitSize
    width: implicitWidth
    height: implicitHeight

    Behavior on revealProgress {
        NumberAnimation {
            duration: root.bar && typeof root.bar.motionDuration === "function" ? root.bar.motionDuration(600) : 600
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: SystemTray.items

        function onValuesChanged() {
            root.sourceRevision++;
        }
    }

    Item {
        z: 1
        width: root.width
        height: root.hitSize + root.bottomHitPadding

        HoverHandler {
            id: trayHover

            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    if (!root.expanded)
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    collapseTimer.restart();
                }
            }
        }
    }

    Timer {
        id: openTimer

        interval: 200
        onTriggered: if (trayHover.hovered && root.visible)
            root.expanded = true
    }

    Timer {
        id: collapseTimer

        interval: 120
        onTriggered: if (!root.activeMenu)
            root.expanded = false
    }

    Rectangle {
        id: expandButton

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(expandIcon.controlGlyphWidth + root.px(16))
        height: root.hitSize
        radius: root.px(4)
        color: expandMouse.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : expandMouse.containsMouse || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
        activeFocusOnTab: true
        readonly property bool tooltipHovered: expandMouse.containsMouse

        Accessible.role: Accessible.Button
        Accessible.name: root.expanded ? "Collapse application tray" : "Expand application tray"
        Accessible.onPressAction: root.toggle()

        OverflowIcon {
            id: expandIcon

            anchors.centerIn: parent
            pointsLeft: !root.expanded
            color: Commons.Color.bar.text
        }

        BarMouseArea {
            id: expandMouse

            bar: root.bar
            forwardPress: function (button) {
                if (button !== Qt.LeftButton)
                    return false;
                root.toggle();
                return true;
            }

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (root.bar)
                root.bar.showTooltip(expandButton, root.expanded ? "Collapse application tray" : "Expand application tray")
            onExited: if (root.bar)
                root.bar.hideTooltip(expandButton)
            onClicked: {
                if (root.bar)
                    root.bar.hideTooltip(expandButton);
                root.toggle();
            }
        }

        Keys.onSpacePressed: root.toggle()
        Keys.onReturnPressed: root.toggle()
        Keys.onEnterPressed: root.toggle()
    }

    Flickable {
        id: trayViewport

        x: expandButton.width
        anchors.top: parent.top
        width: root.revealExtent
        height: root.hitSize + root.bottomHitPadding
        contentWidth: root.drawerExtent
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            anchors.top: parent.top
            spacing: root.itemGap

            Repeater {
                id: trayRepeater

                model: root.activeItems

                delegate: Item {
                    id: trayItem

                    required property var modelData
                    readonly property string accessibleLabel: String(modelData.tooltipTitle || modelData.title || modelData.id || "Tray application")
                    readonly property bool tooltipHovered: trayMouse.containsMouse
                    readonly property string hintText: HintLogic.tray(accessibleLabel)
                    readonly property bool exposed: root.expanded && x >= trayViewport.contentX && x + width <= trayViewport.contentX + trayViewport.width + 0.5

                    width: root.slotWidth
                    height: root.hitSize
                    activeFocusOnTab: true

                    function activatePrimary() {
                        if (modelData.onlyMenu && modelData.hasMenu)
                            trayMenu.toggle();
                        else {
                            if (root.activeMenu)
                                root.activeMenu.close();
                            modelData.activate();
                        }
                    }

                    function triggerPress(button) {
                        if (root.bar)
                            root.bar.hideTooltip(trayItem);
                        if (button === Qt.RightButton) {
                            if (!modelData.hasMenu)
                                return false;
                            trayMenu.toggle();
                            return true;
                        }
                        if (button === Qt.MiddleButton) {
                            if (root.activeMenu)
                                root.activeMenu.close();
                            modelData.secondaryActivate();
                            return true;
                        }
                        if (button === Qt.LeftButton) {
                            activatePrimary();
                            return true;
                        }
                        return false;
                    }

                    function syncClickRegistration() {
                        if (!root.bar)
                            return;
                        if (exposed)
                            root.bar.registerClickTarget(trayItem);
                        else
                            root.bar.unregisterClickTarget(trayItem);
                    }

                    onExposedChanged: syncClickRegistration()
                    Component.onCompleted: syncClickRegistration()
                    Component.onDestruction: if (root.bar)
                        root.bar.unregisterClickTarget(trayItem)

                    function openContextMenu() {
                        if (!modelData.hasMenu)
                            return false;
                        trayMenu.open = true;
                        return true;
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: accessibleLabel
                    Accessible.description: modelData.hasMenu ? "Tray application; context menu available" : "Tray application"
                    Accessible.onPressAction: activatePrimary()

                    Rectangle {
                        anchors.fill: parent
                        radius: root.px(4)
                        color: trayMouse.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : trayMouse.containsMouse || trayItem.activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
                    }

                    TrayIcon {
                        anchors.centerIn: parent
                        source: trayItem.modelData.icon
                        iconSize: root.px(20) * 0.67
                        foreground: Commons.Color.bar.text
                    }

                    Rectangle {
                        visible: trayMenu.open || trayItem.activeFocus
                        width: Math.max(root.px(10), Math.round(parent.width * 0.55))
                        height: root.px(2)
                        radius: height / 2
                        color: Commons.Color.accent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                    }

                    TrayContextMenu {
                        id: trayMenu

                        anchorItem: trayItem
                        menu: trayItem.modelData.menu || null
                        bar: root.bar
                        uiScale: root.uiScale
                    }

                    Connections {
                        target: trayMenu

                        function onOpenChanged() {
                            if (trayMenu.open) {
                                root.activeMenu = trayMenu;
                                openTimer.stop();
                                collapseTimer.stop();
                                root.expanded = true;
                            } else if (root.activeMenu === trayMenu) {
                                root.activeMenu = null;
                                if (!trayHover.hovered)
                                    collapseTimer.restart();
                            }
                        }
                    }

                    BarMouseArea {
                        id: trayMouse

                        bar: root.bar
                        forwardPress: function (button) {
                            return trayItem.triggerPress(button);
                        }

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (root.bar)
                            root.bar.showTooltip(trayItem, trayItem.hintText)
                        onExited: if (root.bar)
                            root.bar.hideTooltip(trayItem)
                        onPressed: function (event) {
                            if (event.button === Qt.RightButton) {
                                trayItem.triggerPress(event.button);
                                event.accepted = true;
                            }
                        }
                        onClicked: function (event) {
                            if (event.button !== Qt.RightButton)
                                trayItem.triggerPress(event.button);
                        }
                        onWheel: function (wheel) {
                            trayItem.modelData.scroll(wheel.angleDelta.y, false);
                        }
                    }

                    Keys.onSpacePressed: activatePrimary()
                    Keys.onReturnPressed: activatePrimary()
                    Keys.onEnterPressed: activatePrimary()
                    Keys.onMenuPressed: {
                        trayItem.openContextMenu();
                    }
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier && modelData.hasMenu) {
                            trayItem.openContextMenu();
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
