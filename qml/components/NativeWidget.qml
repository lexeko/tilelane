pragma ComponentBehavior: Bound

import QtQuick

StatusControl {
    id: root

    required property string moduleName
    property var registry: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    // Optional presentation adjustments for existing icon-only widgets.
    property real visualScale: 1
    property real visualVerticalOffset: 0
    property bool iconOnly: false
    readonly property bool available: nativeHost.available && nativeHost.implicitWidth > 0
    readonly property real contentScale: Math.min(visualScale, px(32) / Math.max(1, nativeHost.implicitHeight))

    nativeInput: true
    opened: nativeHost.opened
    implicitWidth: available ? (iconOnly ? px(30) : Math.max(px(30), nativeHost.implicitWidth * contentScale)) : 0
    accessibleName: nativeHost.entry && nativeHost.entry.metadata ? String(nativeHost.entry.metadata.displayName || moduleName) : moduleName
    activation: function (button) {
        return nativeHost.trigger(button);
    }

    function nativeState() {
        return nativeHost.capabilityState();
    }

    HostedBarWidget {
        id: nativeHost

        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.visualVerticalOffset
        scale: root.contentScale
        moduleName: root.moduleName
        registry: root.registry
        bar: root.bar
        settings: root.settings
        fallbackEntryPoint: root.fallbackEntryPoint
        alignPanelToHost: true
        showVisual: true
    }
}
