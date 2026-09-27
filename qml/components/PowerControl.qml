pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "../StatusLogic.js" as StatusLogic
import qs.Commons as Commons

Rectangle {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property var nativeSettings: ({})
    property real uiScale: 1
    readonly property var device: UPower.displayDevice
    readonly property bool configured: barWidgetRegistry && barWidgetRegistry.widgets && barWidgetRegistry.widgets["omarchy.power"] !== undefined
    readonly property bool batteryPresent: !!device && device.isPresent
    readonly property real batteryFraction: batteryPresent ? StatusLogic.clampFraction(device.percentage) : 0
    readonly property bool fullyCharged: batteryPresent && device.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: batteryPresent && !UPower.onBattery
    readonly property bool thresholdActive: {
        if (!batteryPresent || UPower.onBattery || device.state === UPowerDeviceState.Discharging)
            return false;
        if (device.state === UPowerDeviceState.PendingCharge)
            return true;
        if (fullyCharged && batteryFraction < 0.99)
            return true;
        return device.state === UPowerDeviceState.Charging && batteryFraction < 0.99 && (Number(device.changeRate || 0) <= 0.2 || Number(device.timeToFull || 0) >= 8 * 60 * 60);
    }
    readonly property string icon: StatusLogic.batteryIcon(batteryPresent, batteryFraction, charging, fullyCharged, thresholdActive)
    readonly property int percentage: Math.round(batteryFraction * 100)
    readonly property bool showPercentage: nativeSettings && nativeSettings.showPercentage === true
    readonly property bool tooltipHovered: pointer.containsMouse
    readonly property string hintText: "Battery " + percentage + "%"

    function px(value) {
        return value * uiScale;
    }

    function activate(button) {
        return nativeHost.trigger(button);
    }

    function nativeState() {
        const state = nativeHost.capabilityState();
        state.configured = configured;
        state.batteryPresent = batteryPresent;
        return state;
    }

    visible: configured && batteryPresent && icon !== ""
    width: visible ? Math.max(px(30), powerContent.implicitWidth + px(12)) : 0
    height: px(32)
    radius: px(4)
    color: nativeHost.opened ? Commons.Style.selectedAccentFill : pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    border.color: Commons.Color.accent
    border.width: activeFocus ? Math.max(1, Math.round(px(1))) : 0
    activeFocusOnTab: visible

    Accessible.role: Accessible.Button
    Accessible.name: "Battery " + percentage + "%"
    Accessible.description: "Open power panel"
    Accessible.onPressAction: activate(Qt.LeftButton)

    HostedBarWidget {
        id: nativeHost

        clickTarget: pointer

        anchors.fill: parent
        moduleName: "omarchy.power"
        registry: root.barWidgetRegistry
        bar: root.bar
        settings: root.nativeSettings
        fallbackEntryPoint: "Panel.qml"
        lazy: true
    }

    Row {
        id: powerContent

        anchors.centerIn: parent
        spacing: root.px(4)

        Text {
            visible: root.showPercentage
            anchors.verticalCenter: parent.verticalCenter
            text: root.percentage + "%"
            color: Commons.Color.bar.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            renderType: Text.NativeRendering
        }

        TextMetrics {
            id: referenceMetrics

            font.family: Commons.Style.font.family
            font.pixelSize: root.px(16)
            text: "󰁹"
        }

        TextMetrics {
            id: glyphMetrics

            font: glyph.font
            text: glyph.text
        }

        Text {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Commons.Color.bar.text
            font.family: Commons.Style.font.family
            font.pixelSize: Math.max(1, Math.round(root.px(16) * root.px(20) * 0.67 / Math.max(1, referenceMetrics.tightBoundingRect.width, referenceMetrics.tightBoundingRect.height)))
            renderType: Text.NativeRendering
        }
    }

    BarMouseArea {
        id: pointer

        bar: root.bar
        forwardPress: function (button) {
            return root.activate(button);
        }

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.bar)
            root.bar.showTooltip(root, root.hintText)
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
        onClicked: function (event) {
            if (root.bar)
                root.bar.hideTooltip(root);
            root.forceActiveFocus();
            root.activate(event.button);
        }
    }

    Keys.onSpacePressed: activate(Qt.LeftButton)
    Keys.onReturnPressed: activate(Qt.LeftButton)
    Keys.onEnterPressed: activate(Qt.LeftButton)
}
