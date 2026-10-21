import QtQuick
import QtQuick.Window
import "../TrayIconSource.js" as TrayIconSource

Item {
    id: root

    required property string source
    required property real iconSize
    required property color foreground
    readonly property string safeSource: TrayIconSource.themeSource(source)
    readonly property bool symbolic: safeSource.split("?")[0].endsWith("-symbolic")

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: trayImage
        objectName: "trayImage"

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        source: root.safeSource
        layer.enabled: root.symbolic
        layer.effect: ShaderEffect {
            property var source
            property color foreground: root.foreground

            fragmentShader: Qt.resolvedUrl("../shaders/tray-symbolic.frag.qsb")
        }
    }
}
