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
    readonly property var dropboxIconContent: {
        if (moduleName !== "omarchy.dropbox" || !nativeHintTarget || !nativeHintTarget.iconComponent)
            return null;
        const objects = nativeHost.nativeObjects;
        for (let index = 0; index < objects.length; index++) {
            const object = objects[index];
            if (object && "sourceBounds" in object && "sourceComponent" in object && object.sourceComponent === nativeHintTarget.iconComponent)
                return object;
        }
        return null;
    }
    // Standard single-glyph buttons share Tilelane's renderer automatically.
    // Keep compound widgets and custom icon components in their native form.
    readonly property bool normalizeGlyph: !!nativeHintTarget && "iconComponent" in nativeHintTarget && nativeHintTarget.iconComponent === null && nativeHintTarget.labelVisible === false && Array.from(String(nativeHintTarget.text || "")).length === 1 && nativeHost.nativeObjects.filter(object => object && typeof object.triggerPress === "function").length === 1

    nativeInput: true
    opened: nativeHost.opened
    implicitWidth: available ? Math.max(minimumWidth, nativeHost.implicitWidth * contentScale) : 0
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
        opacity: root.normalizeGlyph ? 0 : 1
        moduleName: root.moduleName
        registry: root.registry
        bar: root.bar
        settings: root.settings
        fallbackEntryPoint: root.fallbackEntryPoint
        alignPanelToHost: true
        showVisual: true
    }

    // The native Dropbox artwork is smaller than its optical canvas. Enlarge
    // only the painted icon while leaving the widget slot and hit area intact.
    Binding {
        target: root.dropboxIconContent
        property: "scale"
        value: root.dropboxIconContent && root.nativeHintTarget ? Math.min(1.5, Math.max(1, root.nativeHintTarget.opticalSize / Math.max(1, root.dropboxIconContent.paintedWidth))) : 1
        when: root.dropboxIconContent !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    OpticalStatusGlyph {
        visible: root.normalizeGlyph && root.available && root.nativeHintTarget.visible
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        uiScale: root.uiScale
        text: root.normalizeGlyph ? root.nativeHintTarget.text : ""
        fontFamily: root.normalizeGlyph ? root.nativeHintTarget.fontFamily : "monospace"
        color: root.normalizeGlyph ? (root.nativeHintTarget.active && root.nativeHintTarget.useActiveColor ? root.nativeHintTarget.activeColor : root.nativeHintTarget.foreground) : "transparent"
        opacity: root.normalizeGlyph ? root.nativeHintTarget.opacity : 1
        rotation: root.normalizeGlyph ? root.nativeHintTarget.textRotation : 0
    }
}
