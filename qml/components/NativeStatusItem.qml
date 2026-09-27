pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Rectangle {
    id: root

    required property string moduleName
    required property string presentation
    property var registry: null
    property var bar: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    property real uiScale: 1
    readonly property real targetIconSize: uiScale * 20 * 0.67
    readonly property var statusOwner: presentation === "text" ? nativeHost.hostItem : findLabeledModule(nativeHost.hostItem, 0)
    readonly property string statusText: {
        if (!statusOwner)
            return "";
        if (presentation === "text")
            return String(statusOwner.layoutLabel || "");
        return String(statusOwner.label || "");
    }
    readonly property bool statusVisible: nativeHost.available && statusText !== "" && (root.moduleName !== "omarchy.keyboard-layout" || statusOwner.multipleLayouts === true)
    readonly property bool tooltipHovered: pointer.containsMouse
    readonly property string hintText: {
        if (root.moduleName === "omarchy.keyboard-layout")
            return "Language: " + root.statusText;
        return "Weather";
    }

    function findLabeledModule(owner, depth) {
        if (!owner || depth > 4)
            return null;
        if ("moduleName" in owner && String(owner.moduleName || "") === root.moduleName && "label" in owner)
            return owner;
        const objects = owner.data ? owner.data : [];
        for (let index = 0; index < objects.length; index++) {
            const object = objects[index];
            if (object && "item" in object && object.item) {
                const loaded = findLabeledModule(object.item, depth + 1);
                if (loaded)
                    return loaded;
            }
            const nested = findLabeledModule(object, depth + 1);
            if (nested)
                return nested;
        }
        return null;
    }

    function activate(button) {
        const item = nativeHost.hostItem;
        if (!item)
            return false;
        if (root.moduleName === "omarchy.keyboard-layout" && typeof item.cycleLayout === "function") {
            item.cycleLayout();
            return true;
        }
        if (root.moduleName === "omarchy.weather") {
            if (button === Qt.MiddleButton && typeof item.refresh === "function") {
                item.refresh();
                return true;
            }
            if (button === Qt.RightButton && root.bar && typeof root.bar.run === "function") {
                root.bar.run("omarchy-notification-send \"$(omarchy-weather-status)\"");
                return true;
            }
        }
        return nativeHost.trigger(button);
    }

    visible: statusVisible
    implicitWidth: presentation === "text" ? Math.max(uiScale * 30, statusLabel.implicitWidth + uiScale * 12) : uiScale * 30
    implicitHeight: uiScale * 32
    width: visible ? implicitWidth : 0
    height: implicitHeight
    radius: uiScale * 4
    color: pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: presentation === "text" ? "Keyboard layout " + statusText : "Weather"
    Accessible.description: presentation === "text" ? "Switch keyboard layout" : "Open weather"
    Accessible.onPressAction: activate(Qt.LeftButton)

    HostedBarWidget {
        id: nativeHost

        clickTarget: pointer

        anchors.fill: parent
        moduleName: root.moduleName
        registry: root.registry
        bar: root.bar
        settings: root.settings
        fallbackEntryPoint: root.fallbackEntryPoint
        alignPanelToHost: root.moduleName === "omarchy.weather"
    }

    Text {
        id: statusLabel

        visible: root.presentation === "text"
        anchors.centerIn: parent
        text: root.statusText
        color: Commons.Color.bar.text
        font.family: Commons.Style.font.family
        font.pixelSize: Math.max(1, Commons.Style.font.body - 0.5)
        renderType: Text.NativeRendering
    }

    Rectangle {
        visible: nativeHost.opened || root.activeFocus
        width: Math.max(root.uiScale * 10, Math.round(parent.width * 0.55))
        height: root.uiScale * 2
        radius: height / 2
        color: Commons.Color.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    OpticalStatusGlyph {
        visible: root.presentation === "icon"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.uiScale
        text: root.statusText
        color: Commons.Color.bar.text
        fontFamily: Commons.Style.font.family
        opticalSize: root.targetIconSize
        sourceFontSize: Math.max(32, root.uiScale * 64)
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
            root.activate(event.button);
        }
    }

    Keys.onSpacePressed: activate(Qt.LeftButton)
    Keys.onReturnPressed: activate(Qt.LeftButton)
    Keys.onEnterPressed: activate(Qt.LeftButton)
}
