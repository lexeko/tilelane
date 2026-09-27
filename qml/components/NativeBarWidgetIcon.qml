pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property string moduleName
    property var registry: null
    property var bar: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    property real uiScale: 1
    property real baseVisualSize: 13
    property real visualVerticalOffset: 0
    readonly property real targetVisualSize: uiScale * 20 * 0.67
    readonly property real contentScale: targetVisualSize / Math.max(1, baseVisualSize)
    readonly property bool available: nativeHost.available && nativeHost.implicitWidth > 0
    readonly property bool opened: nativeHost.opened

    function activate(button) {
        return nativeHost.trigger(button);
    }

    function nativeState() {
        const state = nativeHost.capabilityState();
        state.visible = root.available;
        return state;
    }

    implicitWidth: available ? uiScale * 30 : 0
    implicitHeight: uiScale * 32
    width: implicitWidth
    height: implicitHeight

    Item {
        anchors.fill: parent
        clip: true

        HostedBarWidget {
            id: nativeHost

            width: implicitWidth
            height: implicitHeight
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.visualVerticalOffset
            scale: root.contentScale
            transformOrigin: Item.Center
            moduleName: root.moduleName
            registry: root.registry
            bar: root.bar
            clickTarget: pointer
            settings: root.settings
            fallbackEntryPoint: root.fallbackEntryPoint
            showVisual: true
        }
    }

    BarMouseArea {
        id: pointer

        z: -1
        bar: root.bar
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        forwardPress: function (button) {
            return root.activate(button);
        }
        onClicked: function (event) {
            root.activate(event.button);
        }
    }
}
