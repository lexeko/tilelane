pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons as Commons
import qs.Ui as Ui

Ui.KeyboardPanel {
    id: root

    property var menu: null
    property real uiScale: 1
    property var submenuStack: []
    property bool settling: false
    property var rootHandle: null
    readonly property var entries: submenuStack.length ? submenuStack[submenuStack.length - 1].opener.children.values || [] : opener.children.values || []
    readonly property string submenuTitle: submenuStack.length ? submenuStack[submenuStack.length - 1].title : ""

    function px(value) {
        return value * uiScale;
    }

    function label(entry) {
        return String(entry ? entry.text || "" : "").replace(/&&/g, "\u0001").replace(/&/g, "").replace(/\u0001/g, "&");
    }

    function close() {
        open = false;
    }

    function toggle() {
        open = !open;
    }

    function resetLevels() {
        const previous = submenuStack;
        submenuStack = [];
        for (let index = previous.length - 1; index >= 0; index--)
            previous[index].opener.destroy();
        list.contentY = 0;
        settle.stop();
        settling = false;
    }

    function selectFirst() {
        list.currentIndex = -1;
        step(1);
        list.contentY = 0;
    }

    function step(direction) {
        if (!entries.length)
            return;
        let index = list.currentIndex;
        for (let attempt = 0; attempt < entries.length; attempt++) {
            index = (index + direction + entries.length) % entries.length;
            if (!entries[index].isSeparator && entries[index].enabled) {
                list.currentIndex = index;
                list.positionViewAtIndex(index, ListView.Contain);
                return;
            }
        }
    }

    function enter(entry) {
        if (!entry || !entry.enabled || entry.isSeparator || settling)
            return;
        if (entry.hasChildren) {
            const nested = openerFactory.createObject(root, {
                "menu": entry
            });
            if (!nested)
                return;
            submenuStack = submenuStack.concat([
                {
                    "opener": nested,
                    "title": label(entry)
                }
            ]);
            settling = true;
            settle.restart();
            selectFirst();
        } else {
            entry.triggered();
            close();
        }
    }

    function back() {
        if (!submenuStack.length || settling)
            return;
        const next = submenuStack.slice();
        const last = next.pop();
        submenuStack = next;
        last.opener.destroy();
        settling = true;
        settle.restart();
        selectFirst();
    }

    onMenuChanged: {
        if (open)
            close();
        else
            resetLevels();
    }
    onEntriesChanged: {
        if (open)
            selectFirst();
    }
    Component.onDestruction: {
        if (bar)
            bar.releasePopout(root);
        resetLevels();
    }

    contentWidth: fittedContentWidth(px(260))
    contentHeight: fittedContentHeight(list.contentHeight + header.height, px(420))
    padding: px(8)
    gap: px(7)
    focusTarget: menuFocus

    FocusScope {
        id: menuFocus

        anchors.fill: parent
        focus: root.open

        Connections {
            target: root

            function onOpenChanged() {
                if (root.open) {
                    if (!root.menu) {
                        root.open = false;
                        return;
                    }
                    root.rootHandle = root.menu;
                    root.selectFirst();
                } else {
                    root.resetLevels();
                    root.rootHandle = null;
                }
            }
        }
        QsMenuOpener {
            id: opener

            menu: root.rootHandle
        }

        Component {
            id: openerFactory

            QsMenuOpener {}
        }

        Timer {
            id: settle

            interval: 200
            onTriggered: root.settling = false
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape)
                root.close();
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))
                root.step(1);
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)
                root.step(-1);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace)
                root.back();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.enter(root.entries[list.currentIndex]);
            else if (event.key === Qt.Key_Right) {
                const entry = root.entries[list.currentIndex];
                if (entry && entry.hasChildren)
                    root.enter(entry);
            } else {
                return;
            }
            event.accepted = true;
        }

        Rectangle {
            id: header

            width: parent.width
            height: root.submenuStack.length ? root.px(34) : 0
            visible: height > 0
            radius: root.px(4)
            color: backMouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"

            Accessible.role: Accessible.MenuItem
            Accessible.name: "Back to " + root.submenuTitle
            Accessible.description: "Return to the parent tray menu"
            Accessible.onPressAction: root.back()

            Text {
                anchors.fill: parent
                anchors.leftMargin: root.px(8)
                text: "‹  " + root.submenuTitle
                textFormat: Text.PlainText
                color: Commons.Color.menu.text
                font.family: Commons.Style.font.menuFamily
                font.pixelSize: Commons.Style.font.body
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        ListView {
            id: list

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            model: root.entries
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: list.width
                height: root.px(modelData.isSeparator ? 9 : 32)
                radius: root.px(4)
                color: !modelData.isSeparator && modelData.enabled && (rowMouse.containsMouse || list.currentIndex === index) ? Commons.Color.menu.selectedBackground : "transparent"
                opacity: modelData.isSeparator || modelData.enabled ? 1 : 0.42

                Accessible.role: modelData.isSeparator ? Accessible.Separator : Accessible.MenuItem
                Accessible.name: modelData.isSeparator ? "" : root.label(modelData)
                Accessible.description: !modelData.isSeparator && modelData.hasChildren ? "Submenu" : ""
                Accessible.onPressAction: root.enter(modelData)

                Rectangle {
                    visible: row.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Commons.Style.space(4)
                    anchors.rightMargin: Commons.Style.space(4)
                    height: Commons.Style.spacing.hairline
                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.2)
                }

                Text {
                    visible: !row.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: root.px(8)
                    width: root.px(16)
                    text: row.modelData.checkState === Qt.PartiallyChecked ? "−" : row.modelData.checkState === Qt.Checked ? row.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓" : ""
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    font.family: Commons.Style.font.menuFamily
                    font.pixelSize: Commons.Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: !row.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: root.px(30)
                    anchors.right: submenuGlyph.left
                    anchors.rightMargin: root.px(8)
                    text: root.label(row.modelData)
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    font.family: Commons.Style.font.menuFamily
                    font.pixelSize: Commons.Style.font.body
                    elide: Text.ElideRight
                }

                Text {
                    id: submenuGlyph

                    visible: !row.modelData.isSeparator && row.modelData.hasChildren
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.px(8)
                    text: "›"
                    textFormat: Text.PlainText
                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.72)
                    font.family: Commons.Style.font.menuFamily
                    font.pixelSize: Commons.Style.font.body
                }

                MouseArea {
                    id: rowMouse

                    anchors.fill: parent
                    enabled: !row.modelData.isSeparator && row.modelData.enabled
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: list.currentIndex = row.index
                    onClicked: root.enter(row.modelData)
                }
            }
        }
    }
}
