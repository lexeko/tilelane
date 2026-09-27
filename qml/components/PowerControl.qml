pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "../StatusLogic.js" as StatusLogic
import qs.Commons as Commons

StatusControl {
    id: root

    opened: nativeHost.opened
    accessibleName: "Battery " + percentage + "%"
    accessibleDescription: "Open power panel"

    property var barWidgetRegistry: null
    property var nativeSettings: ({})
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
    hintText: "Battery " + percentage + "%"

    activation: function (button) {
        return nativeHost.trigger(button);
    }

    function nativeState() {
        const state = nativeHost.capabilityState();
        state.configured = configured;
        state.batteryPresent = batteryPresent;
        return state;
    }

    visible: configured && batteryPresent && icon !== ""
    implicitWidth: visible ? Math.max(px(30), powerContent.implicitWidth + px(12)) : 0

    HostedBarWidget {
        id: nativeHost

        clickTarget: root.clickTarget

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
}
