import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons as Commons
import qs.Ui as Ui
import "qml/components"

Window {
    id: window
    visible: true
    width: 800
    height: 320
    color: "black"
    readonly property var names: ["Dropbox", "Tailscale", "bluetooth", "wifi", "quiet", "loud", "battery", "monitor", "weather", "tray"]

    Component {
        id: nativePlugin
        Item {
            property Component artwork: null
            property real nativeHeight: 32
            implicitWidth: 27
            implicitHeight: nativeHeight

            Ui.BarIconButton {
                anchors.fill: parent
                iconComponent: parent.artwork
            }
        }
    }

    Grid {
        id: grid
        columns: 10
        Repeater {
            id: cells
            model: 40
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property string name: window.names[index % 10]
                readonly property real uiScale: [1, 1.25, 1.5, 2][Math.floor(index / 10)]
                readonly property bool custom: name === "Dropbox" || name === "Tailscale"
                property Component artwork: null
                width: 80
                height: 80
                color: "black"

                QtObject {
                    id: registry
                    property var widgets: ({
                            "omarchy.dropbox": {
                                component: nativePlugin,
                                metadata: {}
                            }
                        })
                }

                Component.onCompleted: {
                    if (custom)
                        artwork = Qt.createComponent("file://" + Quickshell.env("OMARCHY_ROOT") + "/shell/plugins/panels/" + name.toLowerCase() + "/" + name + "Icon.qml");
                }

                NativeWidget {
                    id: native
                    anchors.centerIn: parent
                    visible: cell.custom
                    moduleName: "omarchy.dropbox"
                    registry: registry
                    uiScale: cell.uiScale
                    onNativeHostChanged: cell.configureArtwork()
                }

                function configureArtwork() {
                    if (native.nativeHost.hostItem) {
                        native.nativeHost.hostItem.artwork = Qt.binding(() => cell.artwork);
                        // Oversized native widgets must fit the bar without
                        // shrinking their icon below the shared target.
                        native.nativeHost.hostItem.nativeHeight = uiScale === 2 ? 96 : 32;
                    }
                }

                Connections {
                    target: native.nativeHost
                    function onHostItemChanged() {
                        cell.configureArtwork();
                    }
                }

                OpticalStatusGlyph {
                    anchors.centerIn: parent
                    visible: !cell.custom && cell.name !== "tray"
                    uiScale: cell.uiScale
                    color: "white"
                    fontFamily: "JetBrainsMono Nerd Font"
                    text: ({
                            bluetooth: "󰂯",
                            wifi: "󰤨",
                            quiet: "",
                            loud: "",
                            battery: "󰁹",
                            monitor: "󰍹",
                            weather: "\uf185"
                        })[cell.name] || ""
                }

                TrayIcon {
                    anchors.centerIn: parent
                    visible: cell.name === "tray"
                    source: "image://icon/tilelane-status-fixture"
                    foreground: "white"
                    iconSize: 12 * cell.uiScale
                }

                function metrics() {
                    const button = native.nativeHintTarget;
                    const content = native.nativeHost.nativeObjects.find(object => object && "sourceBounds" in object && "sourceComponent" in object && button && object.sourceComponent === button.iconComponent);
                    return {
                        name: name,
                        scale: uiScale,
                        target: 12 * uiScale,
                        contentScale: content ? content.scale : 0,
                        paintedSize: content ? Math.max(content.paintedWidth, content.paintedHeight) * content.scale * native.contentScale : 0
                    };
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            const metrics = [];
            for (let index = 0; index < cells.count; index++)
                metrics.push(cells.itemAt(index).metrics());
            console.log("STATUS_METRICS " + JSON.stringify(metrics));
            grid.grabToImage(function (result) {
                if (!result.saveToFile(Quickshell.env("OUTPUT"))) {
                    console.error("Status icon capture failed");
                    Qt.exit(1);
                    return;
                }
                Qt.quit();
            });
        }
    }
}
