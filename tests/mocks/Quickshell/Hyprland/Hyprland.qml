pragma Singleton

import QtQml

QtObject {
    property var focusedMonitor: null
    property var monitors: ({
            values: []
        })
    property var dispatches: []

    function dispatch(command) {
        dispatches = dispatches.concat([command]);
    }
    property var toplevels: ({
            values: []
        })

    signal rawEvent(var event)

    function refreshToplevels() {
    }
}
