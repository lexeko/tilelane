import QtQuick
import Quickshell.Io

Item {
    id: root
    property var bar: null
    property var settings: ({})
    property string moduleName: "example.nested"
    property string label: "ready"
    IpcHandler {
        enabled: root.settings.ipcEnabled !== false
        target: String(root.settings.ipcTarget || "example.nested")
        function identity(): string {
            return String(root.settings.name);
        }
        function refresh(): void {
            for (const widget of root.bar.moduleWidgets())
                widget.refresh();
        }
    }
    Component.onDestruction: {
        if (!bar || bar.marker !== "alive")
            console.error("LIFECYCLE FAIL: bar destroyed before panel");
    }
}
