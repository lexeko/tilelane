pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../ClockLogic.js" as ClockLogic
import qs.Commons as Commons

StatusControl {
    id: root

    opened: nativeHost.opened
    accessibleName: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy, h:mm AP")
    accessibleDescription: "Open calendar"

    property var barWidgetRegistry: null
    property var nativeSettings: ({})
    property string screenName: ""
    property string format: "h:mm AP"
    readonly property string displayText: clockText.text
    readonly property bool nativeAvailable: nativeHost.available
    hintText: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy, h:mm AP")

    activation: function (button) {
        if (nativeHost.trigger(button))
            return true;
        if (bar && typeof bar.toggleHostPanel === "function")
            return bar.toggleHostPanel("omarchy.clock", screenName, button);
        return false;
    }

    function nativeState() {
        return nativeHost.capabilityState();
    }

    indicatorWidth: clockText.implicitWidth
    implicitWidth: Math.max(px(76), clockText.implicitWidth + px(20))
    implicitHeight: px(36)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    HostedBarWidget {
        id: nativeHost

        clickTarget: root.clickTarget

        anchors.fill: parent
        moduleName: "omarchy.clock"
        registry: root.barWidgetRegistry
        bar: root.bar
        fallbackEntryPoint: "BarWidget.qml"
        alignPanelToHost: true
        settings: root.nativeSettings
    }

    Text {
        id: clockText

        anchors.centerIn: parent
        text: ClockLogic.formatDateTime(clock.date, root.format)
        color: Commons.Color.bar.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
    }
}
