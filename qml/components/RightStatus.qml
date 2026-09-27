import QtQuick
import qs.Commons as Commons

Item {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property var clockSettings: ({})
    property string screenName: ""
    property real uiScale: 1
    property real rightHitPadding: 0
    property bool compact: false
    property string clockFormat: "h:mm AP"
    readonly property real groupGap: uiScale * 18
    readonly property real clockGroupGap: Math.max(0, groupGap - uiScale * 2)
    readonly property bool hasLeadingIcons: trayArea.visible || systemControls.implicitWidth > 0
    property alias tray: trayArea
    property alias controls: panelControls
    property alias power: powerControl
    property alias dropbox: dropboxControl
    property alias nativeStatuses: nativeStatusArea
    property alias clock: clockControl

    implicitWidth: statusRow.implicitWidth
    implicitHeight: statusRow.implicitHeight

    Row {
        id: statusRow

        anchors.fill: parent
        spacing: 0

        TrayArea {
            id: trayArea

            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            excludedItemNames: dropboxControl.available ? ["dropbox"] : []
            maximumDrawerExtent: root.compact ? root.uiScale * 120 : root.uiScale * 300
            uiScale: root.uiScale
        }

        Row {
            id: systemControls

            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            NativeBarWidgetIcon {
                id: dropboxControl

                anchors.verticalCenter: parent.verticalCenter
                moduleName: "omarchy.dropbox"
                registry: root.barWidgetRegistry
                bar: root.bar
                settings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings("omarchy.dropbox") : {
                    "id": "omarchy.dropbox"
                }
                fallbackEntryPoint: "Panel.qml"
                baseVisualSize: Commons.Style.space(12)
                uiScale: root.uiScale
            }

            PanelControls {
                id: panelControls

                anchors.verticalCenter: parent.verticalCenter
                bar: root.bar
                barWidgetRegistry: root.barWidgetRegistry
                compact: root.compact
                uiScale: root.uiScale
            }

            PowerControl {
                id: powerControl

                anchors.verticalCenter: parent.verticalCenter
                bar: root.bar
                barWidgetRegistry: root.barWidgetRegistry
                nativeSettings: root.bar && typeof root.bar.barWidgetSettings === "function" ? root.bar.barWidgetSettings("omarchy.power") : {
                    "id": "omarchy.power"
                }
                uiScale: root.uiScale
            }
        }

        Item {
            width: nativeStatusArea.hasVisibleItems && root.hasLeadingIcons ? root.groupGap : 0
            height: 1
        }

        NativeStatusArea {
            id: nativeStatusArea

            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            barWidgetRegistry: root.barWidgetRegistry
            uiScale: root.uiScale
            visible: !root.compact
            width: visible ? implicitWidth : 0
        }

        Item {
            width: nativeStatusArea.hasVisibleItems ? root.clockGroupGap : root.hasLeadingIcons ? root.groupGap * 2 : 0
            height: 1
        }

        Clock {
            id: clockControl

            rightHitPadding: root.rightHitPadding
            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            barWidgetRegistry: root.barWidgetRegistry
            nativeSettings: root.clockSettings
            screenName: root.screenName
            format: root.clockFormat
            uiScale: root.uiScale
        }
    }
}
