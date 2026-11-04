pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    required property var bar
    readonly property var widgets: bar ? bar.moduleWidgets("omarchy.weather") : []
    readonly property bool active: widgets.length > 0
    property bool networkAvailable: (Networking.devices.values || []).some(device => device.connected === true)
    property bool sleeping: false
    property bool pending: false

    function requestRefresh() {
        if (!active || sleeping)
            return;
        pending = true;
        if (networkAvailable)
            refreshDelay.restart();
    }

    function sleepEvent(line) {
        const value = String(line).trim();
        if (value === "boolean true") {
            sleeping = true;
            pending = false;
            refreshDelay.stop();
        } else if (value === "boolean false") {
            sleeping = false;
            requestRefresh();
        }
    }

    onNetworkAvailableChanged: {
        if (networkAvailable)
            requestRefresh();
        else
            refreshDelay.stop();
    }
    onActiveChanged: {
        if (active) {
            sleepEvents.running = true;
        } else {
            sleeping = false;
            pending = false;
            refreshDelay.stop();
            reconnect.stop();
            sleepEvents.running = false;
        }
    }
    onWidgetsChanged: if (pending)
        requestRefresh()

    property Timer refreshDelay: Timer {
        interval: 2000
        onTriggered: {
            if (!root.active || root.sleeping || !root.networkAvailable)
                return;
            root.pending = false;
            for (const widget of root.widgets) {
                if (widget && typeof widget.refresh === "function")
                    widget.refresh();
            }
        }
    }

    property Process sleepEvents: Process {
        command: ["dbus-monitor", "--system", "type='signal',sender='org.freedesktop.login1',path='/org/freedesktop/login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        stdout: SplitParser {
            onRead: line => root.sleepEvent(line)
        }
        onExited: if (root.active) {
            root.sleeping = false;
            reconnect.restart();
        }
    }

    property Timer reconnect: Timer {
        interval: 30000
        onTriggered: if (root.active)
            root.sleepEvents.running = true
    }

    Component.onCompleted: if (active)
        sleepEvents.running = true
}
