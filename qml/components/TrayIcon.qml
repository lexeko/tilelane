import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../TrayIconSource.js" as TrayIconSource

Item {
    id: root

    required property string source
    property string trayItemId: ""
    required property real iconSize
    required property color foreground
    readonly property string safeSource: TrayIconSource.themeSource(source, trayItemId)
    readonly property bool symbolic: safeSource.split("?")[0].endsWith("-symbolic")
    readonly property bool roamPixmap: /^Roam_status_icon_[0-9]{1,6}$/.test(trayItemId) && source.startsWith("image://qsimage/")
    readonly property string badgeProbePath: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/roam-tray-badge")).replace(/^file:\/\//, ""))
    property bool roamUnread: false
    property bool badgeReady: false
    property int badgeGeneration: 0
    property int runningBadgeGeneration: 0

    function refreshBadge() {
        badgeGeneration++;
        if (!roamPixmap) {
            roamUnread = false;
            return;
        }
        runBadgeProbe();
    }

    function runBadgeProbe() {
        if (!roamPixmap || badgeProbe.running)
            return;
        runningBadgeGeneration = badgeGeneration;
        badgeProbe.command = [badgeProbePath, trayItemId];
        badgeProbe.running = true;
    }

    onSourceChanged: if (badgeReady)
        Qt.callLater(root.refreshBadge)
    onTrayItemIdChanged: if (badgeReady)
        Qt.callLater(root.refreshBadge)
    Component.onCompleted: {
        badgeReady = true;
        refreshBadge();
    }

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

    Rectangle {
        objectName: "roamUnreadBadge"
        visible: root.roamPixmap && root.roamUnread
        x: root.iconSize * 0.62
        y: root.iconSize * 0.10
        width: root.iconSize * 0.25
        height: width
        radius: width / 2
        color: "#ed5656"
    }

    Process {
        id: badgeProbe
        objectName: "roamBadgeProbe"

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (root.runningBadgeGeneration !== root.badgeGeneration || !root.roamPixmap)
                    return;
                const value = text.trim();
                if (value === "1" || value === "0")
                    root.roamUnread = value === "1";
            }
        }
        onExited: {
            if (root.runningBadgeGeneration !== root.badgeGeneration)
                Qt.callLater(root.runBadgeProbe);
        }
    }
}
