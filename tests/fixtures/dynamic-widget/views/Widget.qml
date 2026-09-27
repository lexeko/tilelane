pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
    id: root

    property bool expanded: false
    readonly property bool opened: expanded

    implicitWidth: button.implicitWidth
    implicitHeight: 32

    function open() {
        expanded = true;
    }
    function close() {
        expanded = false;
    }
    function toggle() {
        expanded = !expanded;
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: String(root.setting("label", "Dynamic test"))
        tooltipText: "Dynamic widget test"
        onPressed: function (button) {
            if (button === Qt.LeftButton)
                root.toggle();
        }
    }

    KeyboardPanel {
        bar: root.bar
        anchorItem: button
        owner: root
        open: root.expanded
        contentWidth: 180
        contentHeight: 60
        focusTarget: label
        Text {
            id: label
            anchors.centerIn: parent
            text: String(root.setting("label", "Dynamic test"))
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
}
