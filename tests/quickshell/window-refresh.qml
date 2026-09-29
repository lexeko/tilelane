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
    }
}
