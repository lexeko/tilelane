pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../StatusLogic.js" as StatusLogic
import qs.Commons as Commons

StatusControl {
    id: root

    required property string moduleName
    property var registry: null
    property var settings: ({})
    readonly property var bluetoothAdapter: moduleName === "omarchy.bluetooth" ? Bluetooth.defaultAdapter : null
    readonly property var bluetoothDevices: moduleName === "omarchy.bluetooth" && Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var networkDevices: moduleName === "omarchy.network" && Networking.devices ? Networking.devices.values : []
    readonly property var audioSink: moduleName === "omarchy.audio" ? Pipewire.defaultAudioSink : null
    readonly property string label: ({
            "omarchy.agents": "Agents",
            "omarchy.bluetooth": "Bluetooth",
            "omarchy.network": "Network",
            "omarchy.audio": "Audio",
            "omarchy.monitor": "Displays"
        })[moduleName] || moduleName
    readonly property string iconGlyph: {
        switch (moduleName) {
        case "omarchy.bluetooth":
            return bluetoothIcon();
        case "omarchy.network":
            return networkIcon();
        case "omarchy.audio":
            return audioIcon();
        case "omarchy.monitor":
            return Quickshell.screens.length > 1 ? "󰍺" : "󰍹";
        default:
            return "󱚣";
        }
    }
    readonly property string sizingGlyph: moduleName === "omarchy.audio" && !audioSinkIsHeadphones() ? "" : iconGlyph

    opened: nativeHost.opened
    hintText: label
    accessibleDescription: "Open " + label + " panel"
    activation: function (button) {
        if (button === Qt.RightButton && moduleName === "omarchy.audio") {
            Quickshell.execDetached(["omarchy", "audio", "output", "volume", "mute-toggle"]);
            return true;
        }
        return nativeHost.trigger(button);
    }

    function nativeState() {
        return nativeHost.capabilityState();
    }

    function bluetoothConnected() {
        for (let index = 0; index < bluetoothDevices.length; index++) {
            if (bluetoothDevices[index] && bluetoothDevices[index].connected)
                return true;
        }
        return false;
    }

    function bluetoothIcon() {
        if (!bluetoothAdapter || !bluetoothAdapter.enabled)
            return "󰂲";
        return bluetoothConnected() ? "󰂱" : "󰂯";
    }

    function networkDevice(type) {
        let fallback = null;
        for (let index = 0; index < networkDevices.length; index++) {
            const device = networkDevices[index];
            if (!device || device.type !== type)
                continue;
            if (device.connected)
                return device;
            if (!fallback)
                fallback = device;
        }
        return fallback;
    }

    function connectedWifiNetwork(device) {
        const networks = device && device.networks ? device.networks.values : [];
        for (let index = 0; index < networks.length; index++) {
            if (networks[index] && networks[index].connected)
                return networks[index];
        }
        return null;
    }

    function networkIcon() {
        const wired = networkDevice(DeviceType.Wired);
        if (wired && wired.connected)
            return "󰈀";
        const wifi = connectedWifiNetwork(networkDevice(DeviceType.Wifi));
        if (!wifi)
            return "󰤮";
        return StatusLogic.wifiIcon(true, wifi.signalStrength);
    }

    function audioSinkIsHeadphones() {
        if (!audioSink)
            return false;
        const properties = audioSink.ready && audioSink.properties ? audioSink.properties : ({});
        const description = String([audioSink.name, audioSink.description, audioSink.nickname, properties["device.icon-name"] || "", properties["device.product.name"] || "", properties["node.description"] || "", properties["node.nick"] || ""].join(" ")).toLowerCase();
        return /headphone|headset|earbud|earphone|airpod/.test(description);
    }

    function audioIcon() {
        if (!audioSink || !audioSink.audio || audioSink.audio.muted)
            return "";
        if (audioSinkIsHeadphones())
            return "󰋋";
        const volume = Number(audioSink.audio.volume || 0);
        if (volume >= 0.67)
            return "";
        if (volume >= 0.34)
            return "";
        if (volume > 0)
            return "";
        return "";
    }

    PwObjectTracker {
        objects: root.audioSink ? [root.audioSink] : []
    }

    HostedBarWidget {
        id: nativeHost

        anchors.fill: parent
        moduleName: root.moduleName
        registry: root.registry
        bar: root.bar
        clickTarget: root.clickTarget
        fallbackEntryPoint: "Panel.qml"
        lazy: true
        settings: root.settings
    }

    TextMetrics {
        id: referenceMetrics
        font.family: Commons.Style.font.family
        font.pixelSize: root.px(16)
        text: root.sizingGlyph
    }

    TextMetrics {
        id: glyphMetrics
        font: glyph.font
        text: glyph.text
    }

    Text {
        id: glyph
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        anchors.horizontalCenterOffset: implicitWidth / 2 - (glyphMetrics.tightBoundingRect.x + glyphMetrics.tightBoundingRect.width / 2)
        anchors.verticalCenterOffset: height / 2 - baselineOffset - (glyphMetrics.tightBoundingRect.y + glyphMetrics.tightBoundingRect.height / 2)
        text: root.iconGlyph
        color: Commons.Color.bar.text
        font.family: Commons.Style.font.family
        font.pixelSize: Math.max(1, Math.round(root.px(16) * root.px(20) * 0.67 / Math.max(1, referenceMetrics.tightBoundingRect.width, referenceMetrics.tightBoundingRect.height)))
        renderType: Text.NativeRendering
    }
}
