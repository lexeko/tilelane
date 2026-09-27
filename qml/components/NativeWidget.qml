pragma ComponentBehavior: Bound

import QtQuick

StatusControl {
    id: root

    required property string moduleName
    property var registry: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    readonly property bool available: nativeHost.available && nativeHost.implicitWidth > 0
    // Native widgets include the bar's vertical padding in their implicit
    // height. Fit the full bar, not the smaller hover/underline rectangle.
    readonly property real availableHeight: bar && bar.barHeight > 0 ? bar.barHeight : height
    readonly property real contentScale: Math.min(1, availableHeight / Math.max(1, nativeHost.implicitHeight))
    readonly property var nativeHintTarget: nativeHost.findPressTarget(nativeHost.hostItem, 0)

    nativeInput: true
    opened: nativeHost.opened
    implicitWidth: available ? Math.max(px(30), nativeHost.implicitWidth * contentScale) : 0
    accessibleName: nativeHost.entry && nativeHost.entry.metadata ? String(nativeHost.entry.metadata.displayName || moduleName) : moduleName
    hintText: nativeHintTarget && String(nativeHintTarget.tooltipText || "").trim() !== "" ? String(nativeHintTarget.tooltipText) : accessibleName
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
