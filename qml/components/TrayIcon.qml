import QtQuick
import QtQuick.Window

Item {
    id: root

    required property url source
    required property real iconSize
    required property color foreground
    readonly property bool symbolic: String(source).split("?")[0].endsWith("-symbolic")

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: trayImage

        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
        source: root.source
        layer.enabled: root.symbolic
        layer.effect: ShaderEffect {
            property var source
            property color foreground: root.foreground

            fragmentShader: Qt.resolvedUrl("../shaders/tray-symbolic.frag.qsb")
        }
    }
}
