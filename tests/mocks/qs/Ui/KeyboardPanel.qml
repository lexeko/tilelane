import QtQuick

Item {
    id: root

    property Item anchorItem: null
    property var bar: null
    property bool open: false
    property int contentWidth: 264
    property int contentHeight: 96
    property int padding: 8
    property int gap: 7
    property Item focusTarget: null

    width: contentWidth
    height: contentHeight
    visible: open

    function close() {
        open = false;
    }
}
