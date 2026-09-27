pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons

Rectangle {
    id: root

    property string text: ""
    property real uiScale: 1
    property real maximumTextWidth: uiScale * 360
    readonly property alias labelItem: label
    readonly property real horizontalPadding: uiScale * 10
    readonly property real verticalPadding: uiScale * 7

    implicitWidth: Math.min(maximumTextWidth + horizontalPadding * 2, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: label.implicitHeight + verticalPadding * 2
    width: implicitWidth
    height: implicitHeight
    radius: uiScale * 4
    color: Commons.Color.tooltip.background
    border.color: Commons.Color.tooltip.border
    border.width: Math.max(1, Math.round(uiScale))

    Text {
        id: label

        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.maximumTextWidth)
        text: root.text
        textFormat: Text.PlainText
        color: Commons.Color.tooltip.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }
}
