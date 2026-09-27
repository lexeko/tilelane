import QtQuick
import Quickshell
import Quickshell.Io
import "qml/components"

ShellRoot {
    id: root
    property var registry: ({
            widgets: {
                "example.nested": {
                    metadata: {
                        sourceDir: Quickshell.env("TILELANE_WIDGET_TEST_DIR") + "/plugin"
                    }
                }
            }
        })
    Item {
        id: testBar
        property string marker: "alive"
        property alias nativeIpcRegistry: ipcRegistry
        function moduleWidgets() {
            return [first.item ? first.item.hostItem : null, second.hostItem].filter(item => !!item);
        }
        NativeIpcRegistry {
            id: ipcRegistry
            preferredScreenName: "first"
        }
        Loader {
            id: first
            sourceComponent: HostedBarWidget {
                moduleName: "example.nested"
                registry: root.registry
                bar: testBar
                screenName: "first"
                settings: ({
                        name: "first"
                    })
            }
        }
        HostedBarWidget {
            id: second
            moduleName: "example.nested"
            registry: root.registry
            bar: testBar
            screenName: "second"
            settings: ({
                    name: "second"
                })
        }
    }
    IpcHandler {
        target: "test.control"
        function focus(name: string): void {
            ipcRegistry.preferredScreenName = name;
        }
        function removeFirst(): void {
            first.item.prepareForUnload();
            first.active = false;
        }
        function restoreFirst(): void {
            first.active = true;
        }
        function nested(active: bool): void {
            second.hostItem.panelActive = active;
        }
        function configure(enabled: bool, target: string): void {
            first.item.settings = {
                name: "first",
                ipcEnabled: enabled,
                ipcTarget: target
            };
            second.settings = {
                name: "second",
                ipcEnabled: enabled,
                ipcTarget: target
            };
        }
        function unload(): void {
            ipcRegistry.shutdown();
            if (first.item)
                first.item.prepareForUnload();
            second.prepareForUnload();
            testBar.marker = "gone";
        }
        function state(): string {
            return JSON.stringify({
                first: first.item && first.item.available,
                second: second.available,
                labels: second.nativeObjects.filter(object => object && object.label === "ready").length,
                counts: testBar.moduleWidgets().map(widget => widget.refreshCount)
            });
        }
    }
}
