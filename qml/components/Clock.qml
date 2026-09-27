pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../ClockLogic.js" as ClockLogic
import qs.Commons as Commons

Rectangle {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property var nativeSettings: ({})
    property string screenName: ""
    property string format: "h:mm AP"
    property real uiScale: 1
    property real rightHitPadding: 0
    readonly property string displayText: clockText.text
    readonly property bool nativeAvailable: nativeHost.available
    readonly property bool tooltipHovered: pointer.containsMouse
    readonly property string hintText: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy, h:mm AP")

    function px(value) {
        return value * uiScale;
    }

    function activate(button) {
        if (nativeHost.trigger(button))
            return true;
        if (bar && typeof bar.toggleHostPanel === "function")
            return bar.toggleHostPanel("omarchy.clock", screenName, button);
        return false;
    }

    implicitWidth: Math.max(px(76), clockText.implicitWidth + px(20))
    implicitHeight: px(36)
    radius: px(4)
    color: pointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : pointer.containsMouse || activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy, h:mm AP")
    Accessible.description: "Open calendar"
    Accessible.onPressAction: activate(Qt.LeftButton)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    HostedBarWidget {
        id: nativeHost

        clickTarget: pointer

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

    Rectangle {
        visible: nativeHost.opened || root.activeFocus
        width: clockText.implicitWidth
        height: root.px(2)
        radius: height / 2
        color: Commons.Color.accent
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    BarMouseArea {
        id: pointer

        bar: root.bar
        rightPadding: root.rightHitPadding
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
