pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

StatusControl {
    id: root

    opened: nativeHost.opened
    accessibleName: presentation === "text" ? "Keyboard layout " + statusText : "Weather"
    accessibleDescription: presentation === "text" ? "Switch keyboard layout" : "Open weather"

    required property string moduleName
    required property string presentation
    property var registry: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    readonly property real targetIconSize: uiScale * 20 * 0.67
    property var statusOwner: null
    readonly property string statusText: {
        if (!statusOwner)
            return "";
        if (presentation === "text")
            return String(statusOwner.layoutLabel || "");
        return String(statusOwner.label || "");
    }
    readonly property bool statusVisible: nativeHost.available && statusText !== "" && (root.moduleName !== "omarchy.keyboard-layout" || statusOwner.multipleLayouts === true)
    hintText: {
        if (root.moduleName === "omarchy.keyboard-layout")
            return "Language: " + root.statusText;
        return "Weather";
    }

    function updateStatusOwner() {
        statusOwner = presentation === "text" ? nativeHost.hostItem : nativeHost.nativeObjects.find(object => object && object.moduleName === root.moduleName && "label" in object) || null;
    }

    onPresentationChanged: updateStatusOwner()
    onModuleNameChanged: updateStatusOwner()

    function nativeState() {
        return nativeHost.capabilityState();
    }

    activation: function (button) {
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

    HostedBarWidget {
        id: nativeHost

        clickTarget: root.clickTarget

        anchors.fill: parent
        moduleName: root.moduleName
        registry: root.registry
        bar: root.bar
        settings: root.settings
        fallbackEntryPoint: root.fallbackEntryPoint
        alignPanelToHost: root.moduleName === "omarchy.weather"
        onNativeObjectsChangedForHost: root.updateStatusOwner()
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
}
