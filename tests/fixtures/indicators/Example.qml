import QtQuick

Item {
    id: root

    property var bar: null
    property var settings: ({})
    property string moduleName: ""
    property string indicatorBlock: "inactive"
    property var indicatorHost: null
    property var activeOverride: true
    property bool active: false
    property int refreshes: 0
    implicitWidth: settings.slotWidth || 40
    implicitHeight: 32

    MouseArea {
        anchors.fill: parent
        onClicked: root.active = !root.active
    }

    Connections {
        target: root.indicatorHost
        function onRefreshRequested() {
            root.refreshes++;
        }
    }
}
