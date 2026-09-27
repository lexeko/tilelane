pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui as Ui

Ui.KeyboardPanel {
    id: root

    property string address: ""
    property string title: ""
    property string desktopId: ""
    property bool launcherOnly: false
    property bool minimized: false
    property bool fullscreen: false
    property bool maximized: false
    property bool floating: false
    property var actions: null
    property var applicationCatalog: null
    property var pinnedApplications: null
    property int currentIndex: 0
    readonly property int pinRevision: pinnedApplications ? pinnedApplications.revision : 0
    readonly property var menuItems: buildItems(pinRevision)

    contentWidth: Commons.Style.space(292)
    contentHeight: menuColumn.implicitHeight + Commons.Style.space(16)
    padding: Commons.Style.space(8)
    gap: Commons.Style.space(7)
    focusTarget: menuFocus

    function buildItems(revision) {
        const items = [];
        if (launcherOnly) {
            items.push({
                "action": "launch",
                "glyph": "󰏌",
                "label": "Open",
                "shortcut": "Click",
                "available": applicationCatalog && applicationCatalog.entryForId(desktopId) !== null
            });
            items.push({
                "action": "launch-floating",
                "glyph": "󰉈",
                "label": "Open floating",
                "shortcut": "Ctrl + Click",
                "available": applicationCatalog && applicationCatalog.entryForId(desktopId) !== null
            });
            items.push({
                "divider": true
            });
            items.push({
                "action": "left",
                "glyph": "󰁍",
                "label": "Move left",
                "shortcut": "",
                "available": pinnedApplications && pinnedApplications.pins.indexOf(desktopId) > 0
            });
            items.push({
                "action": "right",
                "glyph": "󰁔",
                "label": "Move right",
                "shortcut": "",
                "available": pinnedApplications && pinnedApplications.pins.indexOf(desktopId) < pinnedApplications.pins.length - 1
            });
            items.push({
                "divider": true
            });
            items.push({
                "action": "unpin",
                "glyph": "󰤰",
                "label": "Unpin from taskbar",
                "shortcut": "",
                "available": desktopId !== ""
            });
            return items;
        }

        if (minimized) {
            items.push({
                "action": "restore",
                "address": address,
                "glyph": "󰁯",
                "label": "Restore",
                "shortcut": "",
                "available": address !== ""
            });
        } else if (maximized) {
            items.push({
                "action": "maximize",
                "address": address,
                "glyph": "󰁯",
                "label": "Restore",
                "shortcut": bar ? bar.shortcut("Full width") : "",
                "available": address !== ""
            });
        } else if (!fullscreen) {
            items.push({
                "action": "maximize",
                "address": address,
                "glyph": "󰖯",
                "label": "Maximize",
                "shortcut": bar ? bar.shortcut("Full width") : "",
                "available": address !== ""
            });
        }
        if (!minimized) {
            items.push({
                "action": "minimize",
                "address": address,
                "glyph": "󰖰",
                "label": "Minimize",
                "shortcut": "",
                "available": address !== ""
            });
        }
        if (!minimized && !fullscreen) {
            items.push({
                "action": "float",
                "address": address,
                "glyph": floating ? "󰝘" : "󰉈",
                "label": floating ? "Tile" : "Float",
                "shortcut": bar ? bar.shortcut("Toggle window floating/tiling") : "",
                "available": address !== ""
            });
        }
        items.push({
            "divider": true
        });
        if (desktopId !== "") {
            const pinned = pinnedApplications && pinnedApplications.isPinned(desktopId);
            items.push({
                "action": pinned ? "unpin" : "pin",
                "glyph": pinned ? "󰤰" : "󰐃",
                "label": pinned ? "Unpin from taskbar" : "Pin to taskbar",
                "shortcut": "",
                "available": pinnedApplications !== null
            });
        }
        items.push({
            "action": "close",
            "address": address,
            "glyph": "󰅖",
            "label": "Close window",
            "shortcut": bar ? bar.shortcut("Close window") : "",
            "available": address !== ""
        });
        return items;
    }

    function firstAvailable() {
        for (let index = 0; index < menuItems.length; index++) {
            if (!menuItems[index].divider && menuItems[index].available)
                return index;
        }
        return 0;
    }

    function nextAvailable(start, offset) {
        let index = start;
        for (let count = 0; count < menuItems.length; count++) {
            index = (index + offset + menuItems.length) % menuItems.length;
            if (!menuItems[index].divider && menuItems[index].available)
                return index;
        }
        return start;
    }

    function invoke(item) {
        if (!item || item.divider || !item.available)
            return;
        if (item.action === "launch" && applicationCatalog)
            applicationCatalog.launch(desktopId);
        else if (item.action === "launch-floating" && applicationCatalog)
            applicationCatalog.launch(desktopId, true);
        else if (item.action === "pin" && pinnedApplications)
            pinnedApplications.pin(desktopId);
        else if (item.action === "unpin" && pinnedApplications)
            pinnedApplications.unpin(desktopId);
        else if (item.action === "left" && pinnedApplications)
            pinnedApplications.move(desktopId, -1);
        else if (item.action === "right" && pinnedApplications)
            pinnedApplications.move(desktopId, 1);
        else if (actions && ["activate", "close", "minimize", "restore", "maximize", "float"].indexOf(item.action) !== -1)
            actions.invoke(item.address, item.action);
        close();
    }

    Component.onDestruction: {
        if (bar && bar.activePopout === root)
            bar.releasePopout(root);
    }

    FocusScope {
        id: menuFocus

        anchors.fill: parent
        focus: root.open
        activeFocusOnTab: true

        Connections {
            target: root

            function onOpenChanged() {
                if (root.open)
                    root.currentIndex = root.firstAvailable();
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.currentIndex = root.nextAvailable(root.currentIndex, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.currentIndex = root.nextAvailable(root.currentIndex, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.invoke(root.menuItems[root.currentIndex]);
                event.accepted = true;
            }
        }

        Column {
            id: menuColumn

            width: parent.width

            Repeater {
                model: root.menuItems

                Rectangle {
                    id: menuRow

                    required property var modelData
                    required property int index
                    readonly property bool available: modelData.available === true

                    width: menuColumn.width
                    height: Commons.Style.space(modelData.divider ? 9 : 40)
                    radius: Commons.Style.space(4)
                    color: !modelData.divider && available && (rowPointer.containsMouse || root.currentIndex === index) ? Commons.Color.menu.selectedBackground : "transparent"
                    opacity: modelData.divider || available ? 1 : 0.42

                    Accessible.role: modelData.divider ? Accessible.Separator : Accessible.MenuItem
                    Accessible.name: String(modelData.label || "")
                    Accessible.description: String(modelData.shortcut || "")
                    Accessible.onPressAction: root.invoke(modelData)

                    Rectangle {
                        visible: menuRow.modelData.divider === true
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Commons.Style.space(4)
                        anchors.rightMargin: Commons.Style.space(4)
                        height: Commons.Style.spacing.hairline
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.2)
                    }

                    Text {
                        id: actionGlyph

                        visible: !menuRow.modelData.divider
                        width: Commons.Style.space(22)
                        anchors.left: parent.left
                        anchors.leftMargin: Commons.Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(menuRow.modelData.glyph || "")
                        color: Commons.Color.menu.text
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Commons.Style.font.family
                        font.pixelSize: Commons.Style.font.body
                    }

                    Text {
                        visible: !menuRow.modelData.divider
                        anchors.left: actionGlyph.right
                        anchors.right: shortcutLabel.left
                        anchors.leftMargin: Commons.Style.space(8)
                        anchors.rightMargin: Commons.Style.space(24)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(menuRow.modelData.label || "")
                        color: Commons.Color.menu.text
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.font.body
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }

                    Text {
                        id: shortcutLabel

                        anchors.right: parent.right
                        anchors.rightMargin: Commons.Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(menuRow.modelData.shortcut || "")
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.62)
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.font.caption
                    }

                    MouseArea {
                        id: rowPointer

                        anchors.fill: parent
                        enabled: !menuRow.modelData.divider && menuRow.available
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: root.currentIndex = menuRow.index
                        onClicked: root.invoke(menuRow.modelData)
                    }
                }
            }
        }
    }
}
