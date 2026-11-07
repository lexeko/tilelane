import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    WindowModel {
        id: windows
    }

    IpcHandler {
        target: "test.windows"

        function state(): string {
            return JSON.stringify({
                count: windows.model.count,
                record: windows.recordFor("0xaaa")
            });
        }

        function retainClosedRecord(): void {
            windows.upsert({
                address: "0xaaa",
                generation: 100,
                title: "Retained after native teardown"
            }, null);
        }
    }
}
