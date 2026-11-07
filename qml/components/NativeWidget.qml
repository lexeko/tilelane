pragma ComponentBehavior: Bound

import QtQuick

StatusControl {
    id: root

    required property string moduleName
    property var registry: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    property var sharedHost: null
    readonly property var nativeHost: sharedHost || localHost
    readonly property bool available: root.nativeHost.available && root.nativeHost.implicitWidth > 0
    // Native widgets include the bar's vertical padding in their implicit
    // height. Fit the full bar, not the smaller hover/underline rectangle.
    readonly property real availableHeight: bar && bar.barHeight > 0 ? bar.barHeight : height
    readonly property real contentScale: Math.min(1, availableHeight / Math.max(1, root.nativeHost.implicitHeight))
    readonly property var nativeHintTarget: root.nativeHost.findPressTarget(root.nativeHost.hostItem, 0)
    readonly property var nativeIconContent: {
        if (!nativeHintTarget || !nativeHintTarget.iconComponent)
            return null;
        const objects = root.nativeHost.nativeObjects;
        for (let index = 0; index < objects.length; index++) {
            const object = objects[index];
            if (object && "sourceBounds" in object && "sourceComponent" in object && object.sourceComponent === nativeHintTarget.iconComponent)
                return object;
        }
        return null;
    }
    function singleCodePoint(value) {
        const text = String(value || "");
        if (text.length === 1) {
            const unit = text.charCodeAt(0);
            return unit < 0xD800 || unit > 0xDFFF;
        }
        if (text.length !== 2)
            return false;
        const first = text.charCodeAt(0);
        const second = text.charCodeAt(1);
        return first >= 0xD800 && first <= 0xDBFF && second >= 0xDC00 && second <= 0xDFFF;
    }
    // Standard single-glyph buttons share Tilelane's renderer automatically.
    // Keep compound widgets and custom icon components in their native form.
    readonly property bool normalizeGlyph: !!nativeHintTarget && "iconComponent" in nativeHintTarget && nativeHintTarget.iconComponent === null && nativeHintTarget.labelVisible === false && singleCodePoint(nativeHintTarget.text) && root.nativeHost.nativeObjects.filter(object => object && typeof object.triggerPress === "function").length === 1

    nativeInput: !sharedHost
    opened: root.nativeHost.opened
    implicitWidth: available ? Math.max(minimumWidth, root.nativeHost.implicitWidth * contentScale) : 0
    accessibleName: root.nativeHost.entry && root.nativeHost.entry.metadata ? String(root.nativeHost.entry.metadata.displayName || moduleName) : moduleName
    hintText: nativeHintTarget && String(nativeHintTarget.tooltipText || "").trim() !== "" ? String(nativeHintTarget.tooltipText) : accessibleName
    activation: function (button) {
        return root.nativeHost.trigger(button);
    }

    function nativeState() {
        const state = root.nativeHost.capabilityState();
        if (sharedHost && bar && typeof bar.widgetScreenName === "function")
            state.screenName = bar.widgetScreenName(root);
        return state;
    }

    HostedBarWidget {
        id: localHost

        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        scale: root.contentScale
        opacity: root.normalizeGlyph ? 0 : 1
        moduleName: root.moduleName
        registry: root.sharedHost ? null : root.registry
        bar: root.bar
        settings: root.settings
        fallbackEntryPoint: root.fallbackEntryPoint
        alignPanelToHost: true
        showVisual: true
    }

    // Native custom icons already fit their painted bounds in Omarchy 4.5.
    // Match the shared target without app-specific enlargement or slot changes.
    Binding {
        target: root.nativeIconContent
        property: "scale"
        value: root.nativeIconContent ? root.statusIconSize / (Math.max(1, root.nativeIconContent.paintedWidth, root.nativeIconContent.paintedHeight) * root.contentScale) : 1
        when: root.nativeIconContent !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    OpticalStatusGlyph {
        visible: root.normalizeGlyph && root.available && root.nativeHintTarget.visible
        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        uiScale: root.uiScale
        opticalSize: root.statusIconCanvas
        opticalPaintedSize: root.statusIconSize
        opticalSizing: root.normalizeGlyph
        text: root.normalizeGlyph ? root.nativeHintTarget.text : ""
        fontFamily: root.normalizeGlyph ? root.nativeHintTarget.fontFamily : "monospace"
        color: root.normalizeGlyph ? (root.nativeHintTarget.active && root.nativeHintTarget.useActiveColor ? root.nativeHintTarget.activeColor : root.nativeHintTarget.foreground) : "transparent"
        opacity: root.normalizeGlyph ? root.nativeHintTarget.opacity : 1
        rotation: root.normalizeGlyph ? root.nativeHintTarget.textRotation : 0
    }
}
