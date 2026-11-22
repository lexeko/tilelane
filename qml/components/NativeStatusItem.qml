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
    property var statusOwner: null
    property bool weatherLabelFallbackApplied: false
    property bool applyingWeatherFallback: false
    // Temporary workaround: keep Omarchy's native weather panel unloaded while
    // closed until upstream bounds forecast response buffering, and backfill
    // the panel's condition glyph from wttr.in when Open-Meteo fails so the
    // hero view does not show a leading em dash next to the temperature.
    readonly property bool lazyWeather: moduleName === "omarchy.weather"
    readonly property string weatherIdleGlyph: "\ue302"
    readonly property string statusText: {
        if (presentation === "text")
            return statusOwner ? String(statusOwner.inputLabel || statusOwner.layoutLabel || "") : "";
        const live = statusOwner ? String(statusOwner.label || "") : "";
        return lazyWeather ? (live || weatherIdleGlyph) : live;
    }
    readonly property bool statusVisible: lazyWeather ? nativeHost.hasLoadSource : nativeHost.available && statusText !== "" && (root.moduleName !== "omarchy.keyboard-layout" || statusOwner.multipleLayouts === true || statusOwner.multipleInputs === true)
    hintText: {
        if (root.moduleName === "omarchy.keyboard-layout")
            return "Language: " + root.statusText;
        return "Weather";
    }

    function syncWeatherFallbackLabel() {
        const owner = root.statusOwner;
        if (!root.lazyWeather || !owner)
            return;
        const current = "current" in owner ? owner.current : null;
        if (!current)
            return;
        if (current.openMeteoWeatherCode !== undefined && current.openMeteoWeatherCode !== null)
            return;
        if (String(owner.label || "") !== "" && !root.weatherLabelFallbackApplied)
            return;
        if (current.weatherCode === undefined || current.weatherCode === null || typeof owner.iconForCode !== "function")
            return;
        const fallbackIcon = String(owner.iconForCode(current.weatherCode, false) || "");
        if (fallbackIcon === "" || String(owner.label || "") === fallbackIcon)
            return;
        root.applyingWeatherFallback = true;
        owner.label = fallbackIcon;
        root.applyingWeatherFallback = false;
        root.weatherLabelFallbackApplied = true;
    }

    function updateStatusOwner() {
        statusOwner = presentation === "text" ? nativeHost.hostItem : nativeHost.nativeObjects.find(object => object && object.moduleName === root.moduleName && "label" in object) || null;
    }

    onStatusOwnerChanged: {
        weatherLabelFallbackApplied = false;
        applyingWeatherFallback = false;
        if (lazyWeather && statusOwner)
            Qt.callLater(root.syncWeatherFallbackLabel);
    }
    onPresentationChanged: updateStatusOwner()
    onModuleNameChanged: updateStatusOwner()

    function nativeState() {
        return nativeHost.capabilityState();
    }

    activation: function (button) {
        if (root.lazyWeather) {
            if (button === Qt.RightButton && root.bar && typeof root.bar.run === "function") {
                root.bar.run("omarchy-notification-send \"$(omarchy-weather-status)\"");
                return true;
            }
            if (button === Qt.MiddleButton) {
                const weatherItem = nativeHost.hostItem;
                if (weatherItem && typeof weatherItem.refresh === "function") {
                    weatherItem.refresh();
                    return true;
                }
                return false;
            }
            return nativeHost.trigger(button);
        }
        const item = nativeHost.hostItem;
        if (!item)
            return false;
        if (root.moduleName === "omarchy.keyboard-layout") {
            if (nativeHost.trigger(button))
                return true;
            if (typeof item.cycleLayout === "function") {
                item.cycleLayout();
                return true;
            }
            return false;
        }
        return nativeHost.trigger(button);
    }

    visible: statusVisible
    implicitWidth: presentation === "text" ? Math.max(minimumWidth, statusLabel.implicitWidth + contentPadding) : minimumWidth
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
        lazy: root.lazyWeather
        alignPanelToHost: root.lazyWeather
        onNativeObjectsChangedForHost: root.updateStatusOwner()
    }

    Connections {
        target: root.lazyWeather ? root.statusOwner : null
        ignoreUnknownSignals: true

        function onCurrentChanged() {
            Qt.callLater(root.syncWeatherFallbackLabel);
        }

        function onLabelChanged() {
            if (!root.applyingWeatherFallback)
                root.weatherLabelFallbackApplied = false;
        }
    }

    Text {
        id: statusLabel

        visible: root.presentation === "text"
        anchors.centerIn: parent
        text: root.statusText
        textFormat: Text.PlainText
        color: Commons.Color.bar.text
        font.family: Commons.Style.font.family
        font.pixelSize: Math.max(1, Commons.Style.font.body - 0.5)
        renderType: Text.NativeRendering
    }

    OpticalStatusGlyph {
        visible: root.presentation === "icon"
        opticalSizing: true
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        text: root.statusText
        color: Commons.Color.bar.text
        fontFamily: Commons.Style.font.family
        uiScale: root.uiScale
        opticalSize: root.statusIconCanvas
        opticalPaintedSize: root.statusIconSize
    }
}
