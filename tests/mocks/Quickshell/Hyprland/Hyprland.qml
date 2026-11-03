pragma Singleton

import QtQml

QtObject {
    property var focusedMonitor: null
    property var monitors: ({
            values: []
        })
    property var dispatches: []
    property bool dispatchFails: false

    function dispatch(command) {
        if (dispatchFails)
            throw new Error("simulated native dispatch failure");
        dispatches = dispatches.concat([command]);
    }
    property var toplevels: ({
            values: []
        })

    signal rawEvent(var event)

    function refreshToplevels() {
    }
}
