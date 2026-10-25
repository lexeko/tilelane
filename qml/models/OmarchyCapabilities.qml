pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool checked: false
    property bool workspaceLayout: false
    property bool nativeMinimize: false

    // Fixed command names only. Discover once per bar instance, not per window
    // or on a timer; a shell restart discovers capabilities after an upgrade.
    property Process probe: Process {
        command: ["sh", "-c", "command -v omarchy-hyprland-workspace-layout-current >/dev/null 2>&1 && printf 'layout\\n'; command -v omarchy-hyprland-window-minimize >/dev/null 2>&1 && printf 'minimize\\n'; :"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n");
                root.workspaceLayout = found.indexOf("layout") !== -1;
                root.nativeMinimize = found.indexOf("minimize") !== -1;
                root.checked = true;
            }
        }
    }
}
