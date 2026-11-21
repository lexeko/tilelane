pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui as Ui

Ui.KeyboardPanel {
    id: root

    signal superStartToggled
    signal semiTransparentToggled

    property bool superStartEnabled: false
    property bool semiTransparent: true
    property int currentIndex: 0
    readonly property var menuItems: [
        {
            "action": "super-start",
            "label": "Open Start with Super"
        },
        {
            "action": "semi-transparent",
            "label": "Semi-transparent taskbar"
        }
    ]

    function checkedFor(action) {
        if (action === "super-start")
            return superStartEnabled;
        if (action === "semi-transparent")
            return semiTransparent;
        return false;
    }

    contentWidth: Commons.Style.space(264)
    contentHeight: menuColumn.implicitHeight + Commons.Style.space(16)
    padding: Commons.Style.space(8)
    gap: Commons.Style.space(7)
    focusTarget: menuFocus

    function step(offset) {
        if (!menuItems.length)
            return;
        currentIndex = (currentIndex + offset + menuItems.length) % menuItems.length;
    }

    function toggleItem(item) {
        if (!item)
            return;
        if (item.action === "super-start")
            superStartToggled();
        else if (item.action === "semi-transparent")
            semiTransparentToggled();
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
                    root.currentIndex = 0;
            }
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.step(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.step(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.toggleItem(root.menuItems[root.currentIndex]);
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
                    readonly property bool checked: root.checkedFor(modelData.action)

                    width: menuColumn.width
                    height: Commons.Style.space(40)
                    radius: Commons.Style.space(4)
                    color: rowPointer.containsMouse || root.currentIndex === index ? Commons.Color.menu.selectedBackground : "transparent"

                    Accessible.role: Accessible.CheckBox
                    Accessible.name: String(modelData.label || "")
                    Accessible.checked: checked
                    Accessible.onPressAction: root.toggleItem(modelData)

                    Rectangle {
                        id: checkbox

                        width: Commons.Style.space(16)
                        height: width
                        radius: Commons.Style.space(3)
                        anchors.left: parent.left
                        anchors.leftMargin: Commons.Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        color: menuRow.checked ? Commons.Style.selectedAccentFill : "transparent"
                        border.color: menuRow.checked ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.menu.text, 0.45)
                        border.width: Math.max(1, Math.round(Commons.Style.space(1)))

                        Text {
                            anchors.centerIn: parent
                            visible: menuRow.checked
                            text: "✓"
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            font.family: Commons.Style.font.menuFamily
                            font.pixelSize: Math.round(checkbox.height * 0.8)
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.left: checkbox.right
                        anchors.right: parent.right
                        anchors.leftMargin: Commons.Style.space(10)
                        anchors.rightMargin: Commons.Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(menuRow.modelData.label || "")
                        textFormat: Text.PlainText
                        color: Commons.Color.menu.text
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.font.body
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: rowPointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.currentIndex = menuRow.index
                        onClicked: root.toggleItem(menuRow.modelData)
                    }
                }
            }
        }
    }
}
