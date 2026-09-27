pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Row {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property real uiScale: 1
    readonly property bool hasVisibleItems: implicitWidth > 0

    spacing: 0

    NativeStatusItem {
        anchors.verticalCenter: parent.verticalCenter
        moduleName: "omarchy.keyboard-layout"
        presentation: "text"
        registry: root.barWidgetRegistry
        bar: root.bar
        settings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings("omarchy.keyboard-layout") : {
            "id": "omarchy.keyboard-layout"
        }
        fallbackEntryPoint: "KeyboardLayout.qml"
        uiScale: root.uiScale
    }

    NativeStatusItem {
        anchors.verticalCenter: parent.verticalCenter
        moduleName: "omarchy.weather"
        presentation: "icon"
        registry: root.barWidgetRegistry
        bar: root.bar
        settings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings("omarchy.weather") : {
            "id": "omarchy.weather"
        }
        fallbackEntryPoint: "BarWidget.qml"
        uiScale: root.uiScale
    }

    NativeBarWidgetIcon {
        anchors.verticalCenter: parent.verticalCenter
        moduleName: "omarchy.system-update"
        registry: root.barWidgetRegistry
        bar: root.bar
        settings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings("omarchy.system-update") : {
            "id": "omarchy.system-update"
        }
        fallbackEntryPoint: "SystemUpdate.qml"
        baseVisualSize: Commons.Style.font.caption
        visualVerticalOffset: root.uiScale
        uiScale: root.uiScale
    }
}
