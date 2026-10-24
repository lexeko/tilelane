pragma Singleton

import QtQml

QtObject {
    property var focusedMonitor: null
    property var toplevels: ({
            values: []
        })

    signal rawEvent(var event)

    function refreshToplevels() {
    }
}
