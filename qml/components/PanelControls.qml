pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../StatusLogic.js" as StatusLogic
import qs.Commons as Commons

Row {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property real uiScale: 1
    property bool compact: false
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int visibleControlCount: {
        const widgets = barWidgetRegistry && barWidgetRegistry.widgets ? barWidgetRegistry.widgets : ({});
        const targets = ["omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor"];
        let count = 0;
        for (let index = 0; index < targets.length; index++) {
            const compactVisible = !compact || targets[index] === "omarchy.network" || targets[index] === "omarchy.audio";
            if (widgets[targets[index]] !== undefined && compactVisible)
                count++;
        }
        return count;
    }

    function px(value) {
        return value * uiScale;
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

    function activateTarget(target, button) {
        for (let index = 0; index < controlRepeater.count; index++) {
            const control = controlRepeater.itemAt(index);
            if (!control || !control.visible || String(control.modelData.target) !== String(target))
                continue;
            return control.activate(button);
        }
        return false;
    }

    function targetState(target) {
        for (let index = 0; index < controlRepeater.count; index++) {
            const control = controlRepeater.itemAt(index);
            if (!control || String(control.modelData.target) !== String(target))
                continue;
            const state = control.hostState();
            state.configured = control.configured;
            state.visible = control.visible;
            return state;
        }
        return {
            "configured": false,
            "visible": false,
            "available": false
        };
    }

    spacing: 0

    PwObjectTracker {
        objects: root.audioSink ? [root.audioSink] : []
    }

    Repeater {
        id: controlRepeater

        // Keep delegates and their panels alive when status glyphs change.
        model: [
            {
                "glyph": "󱚣",
                "label": "Agents",
                "target": "omarchy.agents"
            },
            {
                "label": "Bluetooth",
                "target": "omarchy.bluetooth"
            },
            {
                "label": "Network",
                "target": "omarchy.network"
            },
            {
                "label": "Audio",
                "target": "omarchy.audio"
            },
            {
                "label": "Displays",
                "target": "omarchy.monitor"
            }
        ]

        delegate: Rectangle {
            id: control

            required property var modelData
            readonly property bool configured: root.barWidgetRegistry && root.barWidgetRegistry.widgets && root.barWidgetRegistry.widgets[modelData.target] !== undefined
            readonly property bool tooltipHovered: pointer.containsMouse
            readonly property string hintText: modelData.label
            readonly property string iconGlyph: {
                switch (modelData.target) {
                case "omarchy.bluetooth":
                    return root.bluetoothIcon();
                case "omarchy.network":
                    return root.networkIcon();
                case "omarchy.audio":
                    return root.audioIcon();
                case "omarchy.monitor":
                    return Quickshell.screens.length > 1 ? "󰍺" : "󰍹";
                default:
                    return modelData.glyph;
                }
            }
            readonly property string sizingGlyph: modelData.target === "omarchy.audio" && !root.audioSinkIsHeadphones() ? "" : iconGlyph

            function triggerPress(button) {
                if (root.bar)
                    root.bar.hideTooltip(control);
                return activate(button);
            }

            Component.onCompleted: {
                if (root.bar)
                    root.bar.registerClickTarget(control);
            }
            Component.onDestruction: {
                if (root.bar)
                    root.bar.unregisterClickTarget(control);
            }

            function activate(button) {
                if (button === Qt.RightButton && modelData.target === "omarchy.audio") {
                    Quickshell.execDetached(["omarchy", "audio", "output", "volume", "mute-toggle"]);
                    return true;
                }
                if (nativeHost.trigger(button))
                    return true;
                if (button === Qt.LeftButton && root.bar && typeof root.bar.toggleHostPanel === "function")
                    return root.bar.toggleHostPanel(modelData.target, "", button);
                return false;
            }

            function hostState() {
                return nativeHost.capabilityState();
            }

            visible: configured && (!root.compact || modelData.target === "omarchy.network" || modelData.target === "omarchy.audio")
            width: visible ? root.px(30) : 0
            height: root.px(32)
            radius: root.px(4)
            color: pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
            activeFocusOnTab: true

            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Accessible.description: "Open " + modelData.label + " panel"
            Accessible.onPressAction: activate(Qt.LeftButton)

            HostedBarWidget {
                id: nativeHost

                anchors.fill: parent
                moduleName: control.modelData.target
                registry: root.barWidgetRegistry
                bar: root.bar
                clickTarget: pointer
                fallbackEntryPoint: "Panel.qml"
                lazy: true
                settings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings(control.modelData.target) : {
                    "id": control.modelData.target
                }
            }

            TextMetrics {
                id: referenceMetrics

                font.family: Commons.Style.font.family
                font.pixelSize: root.px(16)
                text: control.sizingGlyph
            }

            Rectangle {
                visible: nativeHost.opened || control.activeFocus
                width: Math.max(root.px(10), Math.round(parent.width * 0.55))
                height: root.px(2)
                radius: height / 2
                color: Commons.Color.accent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
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
                text: control.iconGlyph
                color: Commons.Color.bar.text
                font.family: Commons.Style.font.family
                font.pixelSize: Math.max(1, Math.round(root.px(16) * root.px(20) * 0.67 / Math.max(1, referenceMetrics.tightBoundingRect.width, referenceMetrics.tightBoundingRect.height)))
                renderType: Text.NativeRendering
            }

            BarMouseArea {
                id: pointer

                bar: root.bar
                forwardPress: function (button) {
                    return control.triggerPress(button);
                }

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (root.bar)
                    root.bar.showTooltip(control, control.hintText)
                onExited: if (root.bar)
                    root.bar.hideTooltip(control)
                onClicked: function (event) {
                    control.triggerPress(event.button);
                }
            }

            Keys.onSpacePressed: activate(Qt.LeftButton)
            Keys.onReturnPressed: activate(Qt.LeftButton)
            Keys.onEnterPressed: activate(Qt.LeftButton)
        }
    }
}
