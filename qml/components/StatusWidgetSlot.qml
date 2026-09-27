pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Item {
    id: root

    required property string widgetId
    required property string presentation
    property var settings: ({})
    property var bar: null
    property var registry: null
    property real uiScale: 1
    property real rightHitPadding: 0
    property bool compact: false
    property string screenName: ""
    property bool excludeDropbox: false
    readonly property var item: componentLoader.item
    readonly property var widgetItem: item

    implicitWidth: widgetItem && widgetItem.visible ? widgetItem.implicitWidth : 0
    implicitHeight: widgetItem ? widgetItem.implicitHeight : uiScale * 32
    width: implicitWidth
    height: implicitHeight
    Loader {
        id: componentLoader
        anchors.fill: parent
        sourceComponent: {
            switch (root.presentation) {
            case "panel":
                return panelComponent;
            case "power":
                return powerComponent;
            case "clock":
                return clockComponent;
            case "tray":
                return trayComponent;
            case "text":
            case "weather":
                return statusComponent;
            default:
                return nativeComponent;
            }
        }
    }

    function activate(button) {
        return !!widgetItem && typeof widgetItem.activate === "function" && widgetItem.activate(button);
    }

    function nativeState() {
        const state = widgetItem && typeof widgetItem.nativeState === "function" ? widgetItem.nativeState() : {};
        state.present = true;
        state.configured = true;
        state.visible = visible && width > 0;
        return state;
    }

    Component {
        id: panelComponent
        PanelControl {
            moduleName: root.widgetId
            registry: root.registry
            settings: root.settings
            bar: root.bar
            uiScale: root.uiScale
            rightHitPadding: root.rightHitPadding
        }
    }

    Component {
        id: powerComponent
        PowerControl {
            bar: root.bar
            barWidgetRegistry: root.registry
            nativeSettings: root.settings
            uiScale: root.uiScale
            rightHitPadding: root.rightHitPadding
        }
    }

    Component {
        id: clockComponent
        Clock {
            bar: root.bar
            barWidgetRegistry: root.registry
            nativeSettings: root.settings
            format: String(root.settings.format || "h:mm AP")
            screenName: root.screenName
            uiScale: root.uiScale
            rightHitPadding: root.rightHitPadding
        }
    }

    Component {
        id: trayComponent
        TrayArea {
            bar: root.bar
            excludedItemNames: root.excludeDropbox ? ["dropbox"] : []
            maximumDrawerExtent: root.uiScale * (root.compact ? 120 : 300)
            uiScale: root.uiScale
        }
    }

    Component {
        id: statusComponent
        NativeStatusItem {
            moduleName: root.widgetId
            presentation: root.presentation === "text" ? "text" : "icon"
            fallbackEntryPoint: root.presentation === "text" ? "KeyboardLayout.qml" : "BarWidget.qml"
            registry: root.registry
            settings: root.settings
            bar: root.bar
            uiScale: root.uiScale
            rightHitPadding: root.rightHitPadding
        }
    }

    Component {
        id: nativeComponent
        NativeWidget {
            moduleName: root.widgetId
            registry: root.registry
            settings: root.settings
            bar: root.bar
            uiScale: root.uiScale
            rightHitPadding: root.rightHitPadding
            iconOnly: root.widgetId === "omarchy.dropbox" || root.widgetId === "omarchy.system-update"
            visualScale: root.widgetId === "omarchy.dropbox" ? root.uiScale * 20 * 0.67 / Commons.Style.space(12) : root.widgetId === "omarchy.system-update" ? root.uiScale * 20 * 0.67 / Commons.Style.font.caption : 1
            visualVerticalOffset: root.widgetId === "omarchy.system-update" ? root.uiScale : 0
            fallbackEntryPoint: root.widgetId === "omarchy.dropbox" ? "Panel.qml" : root.widgetId === "omarchy.system-update" ? "SystemUpdate.qml" : ""
        }
    }
}
